defmodule Simulator.WorkerActor do
  @moduledoc """
  GenServer responsible for simulating one shard.

  There are three phases of every iteration:
  - `:remote_plans` - plans are processed. Some of them are accepted, some discarded. Result of the
    processing is distributed among neighboring shards;
  - `:remote_consequences` - consequences derived from the accepted plans are applied to the grid.
    Additionally, signal update is calculated and distributed to the neighboring shards;
  - `:remote_signal` - signal is applied to the grid. Next iteration is started. If iteration's
    number does not exceed the maximum number of iterations set in the cofiguration, plans are
    created and distributed to the neighboring shards;

  First iteration starts with creating plans, so it is in the middle of `:remote_signal` phase.
  """

  use GenServer
  use Simulator.BaseConstants

  import Simulator.Callbacks

  require Logger

  alias Simulator.Printer

  @doc """
  Starts the WorkerActor.
  """
  @spec start(keyword(Nx.t())) :: GenServer.on_start()
  def start(args) do
    GenServer.start(__MODULE__, args)
  end

  @impl true
  def init(args) do
    %{location: location} =
      state =
      args
      |> Map.new()
      |> Map.merge(%{
        iteration: 0,
        start_time: DateTime.utc_now(),
        stashed: [],
        rng: Nx.Random.key(42)
      })

    Printer.create_visualization_directory(location)
    Printer.create_metrics_directory(location)

    {:ok, state}
  end

  @impl true
  def handle_cast({:neighbors, neighbors}, state) do
    # neighbors is a bidirectional map
    neighbors_count = neighbors |> map_size() |> div(2)

    state =
      Map.merge(state, %{
        neighbors: neighbors,
        neighbors_count: neighbors_count,
        processed_neighbors: 0
      })

    {:noreply, state}
  end

  def handle_cast(:start, state), do: start_new_iteration(state)

  def handle_cast(
        {:synchronization, _pid, _grid_slice, _objects_state_slice},
        %{
          processed_neighbors: n,
          neighbors_count: n
        } = state
      ) do
    start_new_iteration(state)
  end

  def handle_cast(
        {:synchronization, pid, grid_slice, objects_state_slice},
        %{
          grid: grid,
          objects_state: objects_state,
          neighbors_count: neighbors_count,
          neighbors: neighbors,
          processed_neighbors: processed_neighbors
        } = state
      ) do
    direction = neighbors[pid]
    grid_location = put_slice_start(grid, direction)
    objects_state_location = put_slice_start(objects_state, direction)

    new_state = %{
      state
      | grid: Nx.put_slice(grid, grid_location, grid_slice),
        objects_state: Nx.put_slice(objects_state, objects_state_location, objects_state_slice),
        processed_neighbors: processed_neighbors + 1
    }

    if neighbors_count == processed_neighbors + 1 do
      start_new_iteration(new_state)
    else
      {:noreply, new_state}
    end
  end

  def handle_cast(message, state) do
    state = Map.update!(state, :stashed, fn stashed -> [message | stashed] end)
    {:noreply, state}
  end

  defp start_new_iteration(%{iteration: iteration} = state) when iteration >= @max_iterations do
    Printer.write_to_file(state)
    {x, y} = state.location
    dt2 = DateTime.utc_now()
    diff = DateTime.diff(dt2, state.start_time, :millisecond)
    Logger.info("all done for #{inspect(x)} #{inspect(y)} in #{inspect(diff)}")
    {:stop, :normal, state}
  end

  defp start_new_iteration(
         %{
           grid: grid,
           iteration: iteration,
           objects_state: objects_state,
           metrics: metrics,
           rng: rng
         } = state
       ) do
    Printer.write_to_file(state)

    {:s, 64} = Nx.type(grid)

    {new_grid, new_objects_state, new_rng} =
      EXLA.jit(fn i, g, os, rng ->
        Iteration.compute(
          i,
          g,
          os,
          rng,
          &create_plan/6,
          &is_update_valid?/2,
          &apply_action/3,
          &apply_consequence/3,
          &generate_signal/1,
          &signal_factor/1
        )
      end).(
        iteration,
        grid,
        objects_state,
        rng
      )

    new_metrics =
      calculate_metrics(metrics, grid, objects_state, new_grid, new_objects_state, iteration)

    new_state = %{
      state
      | grid: new_grid,
        iteration: iteration + 1,
        objects_state: new_objects_state,
        metrics: new_metrics,
        rng: new_rng,
        processed_neighbors: 0
    }

    distribute_margins(new_state)

    if state.neighbors_count == 0 do
      start_new_iteration(new_state)
    else
      {:noreply, new_state}
    end
  end

  defp distribute_margins(%{
         grid: grid,
         objects_state: objects_state,
         neighbors: neighbors,
         location: location
       }) do
    tensors = [grid, objects_state]

    send_to_neighbors(neighbors, :synchronization, tensors, location)
  end

  defp send_to_neighbors(neighbors, message_atom, tensors, location) do
    neighbors
    |> Map.keys()
    |> Enum.filter(fn key -> key in @directions end)
    |> Enum.each(&do_send_to_neighbors(&1, neighbors, message_atom, tensors, location))
  end

  defp do_send_to_neighbors(direction, neighbors, message_atom, tensors, location) do
    neighbor = neighbors[direction]

    message =
      tensors
      |> Enum.map(fn tensor ->
        start = slice_start(tensor, direction)
        length = slice_length(tensor, direction)

        Nx.slice(tensor, start, length)
      end)
      |> Enum.map(&maybe_backend_copy(&1, neighbor))
      |> then(fn tensors -> [message_atom, {:global, location}] ++ tensors end)
      |> List.to_tuple()

    GenServer.cast(neighbor, message)
  end

  defp slice_start(tensor, direction) do
    {x_size, y_size} = get_base_shape(tensor)
    cell_dimensions = get_cell_dimensions(tensor)

    location =
      cond do
        # start in the top left corner
        direction in [@dir_left, @dir_top_left, @dir_top] -> [@margin_size, @margin_size]
        # start in the top right corner
        direction in [@dir_top_right, @dir_right] -> [@margin_size, y_size - 2 * @margin_size]
        # start in the bottom left corner
        direction in [@dir_bottom, @dir_bottom_left] -> [x_size - 2 * @margin_size, @margin_size]
        # start in the bottom right corner
        direction == @dir_bottom_right -> [x_size - 2 * @margin_size, y_size - 2 * @margin_size]
      end

    location ++ cell_dimensions
  end

  defp slice_length(tensor, direction) do
    {x_size, y_size} = get_base_shape(tensor)
    cell_shape = get_cell_shape(tensor)

    length =
      cond do
        # horizontal
        direction in [@dir_top, @dir_bottom] -> [@margin_size, y_size - 2 * @margin_size]
        # vertical
        direction in [@dir_left, @dir_right] -> [x_size - 2 * @margin_size, @margin_size]
        # corners
        true -> [@margin_size, @margin_size]
      end

    length ++ cell_shape
  end

  defp maybe_backend_copy(tensor, {:global, neighbor}) do
    my_node = :erlang.node()

    case :erlang.node(:global.whereis_name(neighbor)) do
      ^my_node ->
        tensor

      _remote_node ->
        Nx.backend_copy(tensor)
    end
  end

  defp put_slice_start(tensor, direction) do
    {x_size, y_size} = get_base_shape(tensor)
    cell_dimensions = get_cell_dimensions(tensor)

    location =
      case direction do
        @dir_top -> [0, @margin_size]
        @dir_top_right -> [0, y_size - @margin_size]
        @dir_right -> [@margin_size, y_size - @margin_size]
        @dir_bottom_right -> [x_size - @margin_size, y_size - @margin_size]
        @dir_bottom -> [x_size - @margin_size, @margin_size]
        @dir_bottom_left -> [x_size - @margin_size, 0]
        @dir_left -> [@margin_size, 0]
        @dir_top_left -> [0, 0]
      end

    location ++ cell_dimensions
  end

  defp get_base_shape(tensor) do
    tensor
    |> Nx.shape()
    |> then(fn shape -> {elem(shape, 0), elem(shape, 1)} end)
  end

  defp get_cell_dimensions(tensor) do
    tensor
    |> Nx.shape()
    |> tuple_size()
    |> then(fn size -> List.duplicate(0, size - 2) end)
  end

  defp get_cell_shape(tensor) do
    tensor
    |> Nx.shape()
    |> Tuple.to_list()
    |> then(fn [_x_size, _y_size | rest] -> rest end)
  end
end
