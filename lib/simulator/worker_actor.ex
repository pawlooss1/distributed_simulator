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
  import Simulator.Helpers

  require Logger

  alias ElixirSense.Log
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
        phase: nil,
        objects: nil,
        old_grid: nil,
        old_objects_state: nil,
        signal_update: nil,
        start_time: DateTime.utc_now(),
        stashed: [],
        rng: Nx.Random.key(42)
      })

    Printer.create_visualization_directory(location)
    Printer.create_metrics_directory(location)

    {:ok, %{state | grid: Nx.backend_transfer(state.grid, Nx.default_backend())}}
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
        :run_iteration,
        %{
          grid: grid,
          iteration: iteration,
          objects_state: objects_state,
          rng: rng,
          fill_signal_iterations: fill_signal_iterations,
          phase: :run_iteration
        } = state
      )
      when fill_signal_iterations > 0 do
        Logger.info("Filling with signals #{fill_signal_iterations}")
    signal_update =
      EXLA.jit_apply(&Signal.calculate_signal_updates/2, [grid, &signal_generators/0])

    final_grid =
      EXLA.jit_apply(&Signal.apply_signal_update/3, [grid, signal_update, &signal_factors/0])

    new_state = %{
      state
      | grid: final_grid,
        fill_signal_iterations: fill_signal_iterations - 1,
        phase: :run_iteration
    }

    GenServer.cast(self(), :run_iteration)

    {:noreply, new_state}
  end

  def handle_cast(
        :run_iteration,
        %{
          grid: grid,
          iteration: iteration,
          objects_state: objects_state,
          rng: rng,
          phase: :run_iteration
        } = state
      ) do
    {new_grid, new_objects_state, new_rng} =
      EXLA.jit(fn i, g, os, rng ->
        Iteration.compute(
          i,
          g,
          os,
          rng,
          &create_plan/4,
          &action_mappings/0,
          &map_state_action/2,
          &consequence_mappings/0,
          &map_state_consequence/2,
          &signal_generators/0,
          &signal_factors/0
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
        objects_state: new_objects_state,
        rng: new_rng,
        phase: :calulate_metrics
    }

    GenServer.cast(self(), :calulate_metrics)

    {:noreply, new_state}
  end

  def handle_cast(
        :create_plans,
        %{
          grid: grid,
          iteration: iteration,
          objects_state: objects_state,
          rng: rng,
          phase: :create_plans
        } = state
      ) do
    {plans, rng} =
      EXLA.jit_apply(&Plans.create_plans/5, [iteration, grid, objects_state, rng, &create_plan/4])

    distribute_plans(state, plans)

    new_state =
      %{
        state
        | objects: plans,
          rng: rng,
          processed_neighbors: 0,
          phase: :remote_plans
      }
      |> unstash_messages()

    {:noreply, new_state}
  end

  def handle_cast(
        {:remote_plans, pid, plans_slice},
        %{
          objects: plans,
          neighbors_count: neighbors_count,
          neighbors: neighbors,
          processed_neighbors: processed_neighbors,
          phase: :remote_plans
        } = state
      ) do
    direction = neighbors[pid]
    location = put_slice_start(plans, direction)

    new_state = %{
      state
      | objects: Nx.put_slice(plans, location, plans_slice),
        processed_neighbors: processed_neighbors + 1
    }

    if neighbors_count == processed_neighbors + 1 do
      GenServer.cast(self(), :process_plans)
      {:noreply, %{new_state | phase: :process_plans}}
    else
      {:noreply, new_state}
    end
  end

  def handle_cast(
        :process_plans,
        %{
          objects: plans,
          objects_state: objects_state,
          rng: rng,
          phase: :process_plans
        } = state
      ) do
    {updated_objects, updated_objects_state, rng} =
      EXLA.jit_apply(&Plans.process_plans/5, [
        plans,
        objects_state,
        rng,
        &action_mappings/0,
        &map_state_action/2
      ])

    distribute_consequences(state, updated_objects, updated_objects_state)

    new_state =
      %{
        state
        | objects: updated_objects,
          objects_state: updated_objects_state,
          rng: rng,
          processed_neighbors: 0,
          phase: :remote_consequences
      }
      |> unstash_messages()

    {:noreply, new_state}
  end

  def handle_cast(
        {:remote_consequences, pid, objects_slice, objects_state_slice},
        %{
          objects: objects,
          objects_state: objects_state,
          neighbors_count: neighbors_count,
          neighbors: neighbors,
          processed_neighbors: processed_neighbors,
          phase: :remote_consequences
        } = state
      ) do
    direction = neighbors[pid]
    location = put_slice_start(objects, direction)

    new_state = %{
      state
      | objects: Nx.put_slice(objects, location, objects_slice),
        objects_state: Nx.put_slice(objects_state, location, objects_state_slice),
        processed_neighbors: processed_neighbors + 1
    }

    if neighbors_count == processed_neighbors + 1 do
      GenServer.cast(self(), :process_consequences)
      {:noreply, %{new_state | phase: :process_consequences}}
    else
      {:noreply, new_state}
    end
  end

  def handle_cast(
        :process_consequences,
        %{
          objects: objects,
          objects_state: objects_state,
          grid: grid,
          phase: :process_consequences
        } = state
      ) do
    {updated_objects, updated_objects_state} =
      EXLA.jit_apply(&Consequences.process_consequences/4, [
        objects,
        objects_state,
        &consequence_mappings/0,
        &map_state_consequence/2
      ])

    updated_grid = Nx.put_slice(grid, [0, 0, 0], add_dimension(updated_objects))

    new_state = %{
      state
      | grid: updated_grid,
        objects_state: updated_objects_state,
        phase: :calc_signal_update
    }

    GenServer.cast(self(), :calc_signal_update)

    {:noreply, new_state}
  end

  def handle_cast(
        :calc_signal_update,
        %{
          grid: grid,
          phase: :calc_signal_update
        } = state
      ) do
    signal_update =
      EXLA.jit_apply(&Signal.calculate_signal_updates/2, [
        grid,
        &signal_generators/0
      ])

    distribute_signal(state, signal_update)

    new_state =
      %{
        state
        | signal_update: signal_update,
          processed_neighbors: 0,
          phase: :remote_signal
      }
      |> unstash_messages()

    {:noreply, new_state}
  end

  def handle_cast(
        {:remote_signal, pid, signal_update_slice},
        %{
          neighbors_count: neighbors_count,
          neighbors: neighbors,
          signal_update: signal_update,
          processed_neighbors: processed_neighbors,
          phase: :remote_signal
        } = state
      ) do
    direction = neighbors[pid]
    location = put_slice_start(signal_update, direction)

    new_state = %{
      state
      | signal_update: Nx.put_slice(signal_update, location, signal_update_slice),
        processed_neighbors: processed_neighbors + 1
    }

    if neighbors_count == processed_neighbors + 1 do
      GenServer.cast(self(), :apply_signal_update)
      {:noreply, %{new_state | phase: :apply_signal_update}}
    else
      {:noreply, new_state}
    end
  end

  def handle_cast(
        :apply_signal_update,
        %{
          grid: grid,
          signal_update: signal_update,
          phase: :apply_signal_update,
          fill_signal_iterations: fill_signal_iterations
        } = state
      ) do
    final_grid =
      EXLA.jit_apply(&Signal.apply_signal_update/3, [
        grid,
        signal_update,
        &signal_factors/0
      ])

    new_state =
      if fill_signal_iterations <= 0 do
        %{state | grid: final_grid, phase: :calulate_metrics}
      else
        %{
          state
          | grid: final_grid,
            phase: :calc_signal_update,
            fill_signal_iterations: fill_signal_iterations - 1
        }
      end

    GenServer.cast(self(), new_state.phase)

    {:noreply, new_state}
  end

  def handle_cast(
        :calculate_metrics,
        %{
          phase: :calulate_metrics,
          fill_signal_iterations: 0
        } = state
      ) do
    start_new_iteration(%{state | fill_signal_iterations: -1})
  end

  def handle_cast(
        :calulate_metrics,
        %{
          metrics: metrics,
          grid: grid,
          old_grid: old_grid,
          objects_state: objects_state,
          old_objects_state: old_objects_state,
          iteration: iteration,
          phase: :calulate_metrics
        } = state
      ) do
    new_metrics =
      calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iteration)

    new_state = %{
      state
      | iteration: iteration + 1,
        metrics: new_metrics
    }

    start_new_iteration(new_state)
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
           neighbors_count: neighbors_count,
           grid: grid,
           objects_state: objects_state,
           fill_signal_iterations: fill_signal_iterations
         } = state
       ) do
    @grid_type = Nx.type(grid)
    Printer.write_to_file(state)

    start_message =
      cond do
        neighbors_count == 0 -> :run_iteration
        fill_signal_iterations > 0 -> :calc_signal_update
        true -> :create_plans
      end

    GenServer.cast(self(), start_message)

    new_state = %{
      state
      | old_grid: grid,
        old_objects_state: objects_state,
        phase: start_message
    }

    {:noreply, new_state}
  end

  defp unstash_messages(%{stashed: stashed} = state) do
    Enum.each(stashed, fn message -> GenServer.cast(self(), message) end)
    %{state | stashed: []}
  end

  defp distribute_plans(state, plans) do
    send_to_neighbors(state.neighbors, :remote_plans, [plans], state.location)
  end

  defp distribute_consequences(state, objects, objects_state) do
    send_to_neighbors(
      state.neighbors,
      :remote_consequences,
      [objects, objects_state],
      state.location
    )
  end

  defp distribute_signal(state, signal_update) do
    send_to_neighbors(state.neighbors, :remote_signal, [signal_update], state.location)
  end

  defp send_to_neighbors(neighbors, message_atom, tensors, location) do
    neighbors
    |> Map.keys()
    |> Enum.filter(fn key -> key in @directions_list end)
    |> Enum.each(&do_send_to_neighbors(&1, neighbors, message_atom, tensors, location))
  end

  defp do_send_to_neighbors(direction, neighbors, message_atom, tensors, location) do
    neighbor = neighbors[direction]

    message =
      tensors
      |> Enum.map(&slice_tensor(&1, direction))
      |> Enum.map(&maybe_backend_copy(&1, neighbor))
      |> then(fn tensors -> [message_atom, {:global, location}] ++ tensors end)
      |> List.to_tuple()

    GenServer.cast(neighbor, message)
  end

  defp slice_tensor(tensor, direction) do
    start = slice_start(tensor, direction)
    length = slice_length(tensor, direction)
    Nx.slice(tensor, start, length)
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
