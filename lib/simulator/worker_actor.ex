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

  alias Simulator.Printer
  alias Simulator.WorkerActor.{Consequences, Plans, Signal}

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

  # For now abandon 'Alternative' from discarded plans in remote plans (no use of it in the
  # current examples). Currently, there is also no use of :remote_signal and :remote_cell_contents
  # states. Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  # def handle_cast({:remote_plans, pid, tensor}, %{phase: :remote_plans} = state) do
  #   %{
  #     grid: grid,
  #     neighbors: neighbors,
  #     neighbors_count: neighbors_count,
  #     objects_state: objects_state,
  #     plans: plans,
  #     processed_neighbors: processed_neighbors
  #   } = state

  #   direction = neighbors[pid]

  #   location = put_slice_start(plans, direction)
  #   plans = Nx.put_slice(plans, location, tensor)

  #   if neighbors_count == processed_neighbors + 1 do
  #     {updated_grid, accepted_plans, updated_objects_state} =
  #       Plans.process_plans(
  #         grid,
  #         plans,
  #         objects_state,
  #         &is_update_valid?/2,
  #         &apply_action/3
  #       )

  #     distribute_consequences(state, updated_grid, updated_objects_state, accepted_plans)

  #     state =
  #       state
  #       |> Map.merge(%{
  #         accepted_plans: accepted_plans,
  #         grid: updated_grid,
  #         old_grid: grid,
  #         objects_state: updated_objects_state,
  #         old_objects_state: objects_state,
  #         phase: :remote_consequences,
  #         plans: plans,
  #         processed_neighbors: 0
  #       })
  #       |> unstash_messages()

  #     {:noreply, state}
  #   else
  #     {:noreply, %{state | plans: plans, processed_neighbors: processed_neighbors + 1}}
  #   end
  # end

  def handle_cast(
        {:remote_consequences, pid, updated_grid, updated_objects_state, new_accepted_plans},
        %{phase: :remote_consequences} = state
      ) do
    %{
      accepted_plans: accepted_plans,
      grid: grid,
      neighbors: neighbors,
      neighbors_count: neighbors_count,
      objects_state: objects_state,
      plans: plans,
      processed_neighbors: processed_neighbors
    } = state

    direction = neighbors[pid]

    location_grid = put_slice_start(grid, direction)
    grid = Nx.put_slice(grid, location_grid, updated_grid)

    location_objects_state = put_slice_start(objects_state, direction)
    objects_state = Nx.put_slice(objects_state, location_objects_state, updated_objects_state)

    location_plans = slice_start_plans(accepted_plans, direction)
    accepted_plans = put_at(accepted_plans, location_plans, new_accepted_plans)

    if neighbors_count == processed_neighbors + 1 do
      {updated_grid, objects_state} =
        Consequences.apply_consequences(
          grid,
          objects_state,
          plans,
          accepted_plans,
          &apply_consequence/3
        )

      signal_update = Signal.calculate_signal_updates(updated_grid, &generate_signal/1)
      # EXLA.jit(fn grid -> Signal.calculate_signal_updates(grid, &generate_signal/1) end, [
      #   updated_grid
      # ])

      distribute_signal(state, signal_update)

      state =
        state
        |> Map.merge(%{
          grid: updated_grid,
          objects_state: objects_state,
          processed_neighbors: 0,
          phase: :remote_signal,
          signal_update: signal_update
        })
        |> unstash_messages()

      {:noreply, state}
    else
      state =
        Map.merge(state, %{
          accepted_plans: accepted_plans,
          grid: grid,
          objects_state: objects_state,
          processed_neighbors: processed_neighbors + 1
        })

      {:noreply, state}
    end
  end

  def handle_cast({:remote_signal, pid, remote_signal_update}, %{phase: :remote_signal} = state) do
    %{
      grid: grid,
      old_grid: old_grid,
      objects_state: objects_state,
      old_objects_state: old_objects_state,
      metrics: metrics,
      iteration: iteration,
      neighbors: neighbors,
      neighbors_count: neighbors_count,
      processed_neighbors: processed_neighbors,
      signal_update: signal_update
    } = state

    direction = neighbors[pid]

    location = put_slice_start(signal_update, direction)
    signal_update = Nx.put_slice(signal_update, location, remote_signal_update)

    if neighbors_count == processed_neighbors + 1 do
      updated_grid = Signal.apply_signal_update(grid, signal_update, &signal_factor/1)

      new_metrics =
        calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iteration)

      state =
        Map.merge(state, %{
          grid: updated_grid,
          metrics: new_metrics,
          iteration: iteration + 1
        })

      start_new_iteration(state)
    else
      state =
        Map.merge(state, %{
          processed_neighbors: processed_neighbors + 1,
          signal_update: signal_update
        })

      {:noreply, state}
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
    IO.inspect("all done for #{x} #{y} in #{diff}")
    {:stop, :normal, state}
  end

  defp start_new_iteration(
         %{
           grid: grid,
           iteration: iteration,
           objects_state: objects_state,
           rng: rng
         } = state
       ) do
    IO.inspect("Iteration no. #{iteration}")
    Printer.write_to_file(state)

    {new_grid, new_objects_state, new_rng} =
      EXLA.jit(fn i, g, os, rng ->
        Iteration.compute(
          i,
          g,
          os,
          rng,
          &create_plan/5,
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

    new_state = %{
      state
      | grid: new_grid,
        iteration: iteration + 1,
        objects_state: new_objects_state
    }

    start_new_iteration(new_state)
  end

  defp start_new_iteration(state) do
    %{
      grid: grid,
      iteration: iteration,
      objects_state: objects_state
    } = state

    maybe_write_metrics(state)

    plans = Plans.create_plans(iteration, grid, objects_state, &create_plan/5)

    distribute_plans(state, plans)

    state =
      state
      |> Map.merge(%{phase: :remote_plans, plans: plans, processed_neighbors: 0})
      |> unstash_messages()

    {:noreply, state}
  end

  defp maybe_write_metrics(%{iteration: iteration, metrics_save_step: metrics_save_step} = state)
       when rem(iteration, metrics_save_step) == 0 do
    Printer.write_to_file(state)
  end

  defp maybe_write_metrics(_) do
  end

  # sends each plan to worker managing cells affected by this plan
  defp distribute_plans(state, plans) do
    tensors = [{plans, &slice_start/2, &slice_length/2}]

    send_to_neighbors(state.neighbors, :remote_plans, tensors, state.location)
  end

  # sends each consequence to worker managing cells affected by this plan consequence
  defp distribute_consequences(state, updated_grid, objects_state, accepted_plans) do
    tensors = [
      {updated_grid, &slice_start/2, &slice_length/2},
      {objects_state, &slice_start/2, &slice_length/2},
      {accepted_plans, &slice_start_plans/2, &slice_length_plans/2}
    ]

    send_to_neighbors(state.neighbors, :remote_consequences, tensors, state.location)
  end

  # sends each signal to worker managing cells affected by this signal
  defp distribute_signal(state, signal_update) do
    tensors = [{signal_update, &slice_start/2, &slice_length/2}]
    send_to_neighbors(state.neighbors, :remote_signal, tensors, state.location)
  end

  defp slice_start(tensor, direction) do
    {x_size, y_size} = get_shape(tensor)
    cell_dimensions = get_cell_dimensions(tensor)

    location =
      cond do
        # start in the top left corner
        direction in [@dir_left, @dir_top_left, @dir_top] -> [1, 1]
        # start in the top right corner
        direction in [@dir_top_right, @dir_right] -> [1, y_size - 2]
        # start in the bottom left corner
        direction in [@dir_bottom, @dir_bottom_left] -> [x_size - 2, 1]
        # start in the bottom right corner
        direction == @dir_bottom_right -> [x_size - 2, y_size - 2]
      end

    location ++ cell_dimensions
  end

  defp slice_length(tensor, direction) do
    {x_size, y_size} = get_shape(tensor)
    cell_shape = get_cell_shape(tensor)

    length =
      cond do
        # horizontal
        direction in [@dir_top, @dir_bottom] -> [1, y_size - 2]
        # vertical
        direction in [@dir_left, @dir_right] -> [x_size - 2, 1]
        # corners
        true -> [1, 1]
      end

    length ++ cell_shape
  end

  defp put_slice_start(tensor, direction) do
    {x_size, y_size} = get_shape(tensor)
    cell_dimensions = get_cell_dimensions(tensor)

    location =
      case direction do
        @dir_top -> [0, 1]
        @dir_top_right -> [0, y_size - 1]
        @dir_right -> [1, y_size - 1]
        @dir_bottom_right -> [x_size - 1, y_size - 1]
        @dir_bottom -> [x_size - 1, 1]
        @dir_bottom_left -> [x_size - 1, 0]
        @dir_left -> [1, 0]
        @dir_top_left -> [0, 0]
      end

    location ++ cell_dimensions
  end

  defp slice_start_plans(tensor, direction) do
    {x_size, y_size} = get_shape(tensor)
    cell_dimensions = get_cell_dimensions(tensor)

    location =
      cond do
        # start in the top left corner
        direction in [@dir_left, @dir_top_left, @dir_top] -> [0, 0]
        # start in the top right corner
        direction in [@dir_top_right, @dir_right] -> [0, y_size - 2]
        # start in the bottom left corner
        direction in [@dir_bottom, @dir_bottom_left] -> [x_size - 2, 0]
        # start in the bottom right corner
        direction == @dir_bottom_right -> [x_size - 2, y_size - 2]
      end

    location ++ cell_dimensions
  end

  defp slice_length_plans(tensor, direction) do
    {x_size, y_size} = get_shape(tensor)
    cell_shape = get_cell_shape(tensor)

    length =
      cond do
        # horizontal
        direction in [@dir_top, @dir_bottom] -> [2, y_size]
        # vertical
        direction in [@dir_left, @dir_right] -> [x_size, 2]
        # corners
        true -> [2, 2]
      end

    length ++ cell_shape
  end

  defp send_to_neighbors(neighbors, message_atom, tensors, location) do
    neighbors
    |> Map.keys()
    |> Enum.filter(fn key -> key in @directions end)
    |> Enum.each(&do_send_to_neighbors(&1, neighbors, message_atom, tensors, location))
  end

  defp do_send_to_neighbors(direction, neighbors, message_atom, tensors, location) do
    message =
      tensors
      |> Enum.map(fn {tensor, start_fun, length_fun} ->
        start = start_fun.(tensor, direction)
        length = length_fun.(tensor, direction)

        Nx.slice(tensor, start, length)
      end)
      |> then(fn tensors -> [message_atom, {:global, location}] ++ tensors end)
      |> List.to_tuple()

    GenServer.cast(neighbors[direction], message)
  end

  defp unstash_messages(%{location: location, stashed: stashed} = state) do
    Enum.each(stashed, fn message -> GenServer.cast({:global, location}, message) end)
    %{state | stashed: []}
  end

  # it uses information that @rejected = 0 and @accepted = 1
  defp put_at(tensor, start, to_put) do
    @rejected
    |> Nx.broadcast(tensor)
    |> Nx.put_slice(start, to_put)
    |> Nx.add(tensor)
  end

  defp get_shape(tensor) do
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
