defmodule Simulator.WorkerActor do
  @moduledoc """
  GenServer responsible for simulating one shard.

  There are four phases of every iteration:
  - `:start_iteration` - if iteration's number does not exceed the
    maxium number of iterations set in the cofiguration, plans are
    created and distributed to the neighboring shards;
  - `:remote_plans` - plans are processed. Some of them are accepted,
    some discarded. Result of the processing is distributed among
    neighboring shards;
  - `:remote_consequences` - consequences derived from the accepted
    plans are applied to the grid. Additionally, signal update is
    calculated and distributed to the neighboring shards;
  - `:remote_signal` - signal is applied to the grid. Next iteration
    is started.
  """

  use GenServer
  use Simulator.BaseConstants

  alias Simulator.Phase.{RemoteConsequences, RemotePlans, RemoteSignal, StartIteration}
  alias Simulator.Printer

  @doc """
  Starts the WorkerActor.

  TODO use some supervisor.
  """
  @spec start(keyword(Nx.t())) :: GenServer.on_start()
  def start(grid: grid, objects_state: objects_state, location: location) do
    GenServer.start(__MODULE__, grid: grid, objects_state: objects_state, location: location)
  end

  @impl true
  def init(grid: grid, objects_state: objects_state, location: location) do
    state = %{
      grid: grid,
      location: location,
      objects_state: objects_state,
      iteration: 1
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:start_iteration, %{iteration: iteration} = state)
      when iteration > @max_iterations do
    {:stop, :normal, state}
  end

  def handle_info({:neighbors, neighbors}, state) do
    state = Map.merge(state, %{
      neighbors: neighbors, 
      neighbors_count: neighbors |> map_size() |> div(2),
      processed_neighbors: 0
      })

    {:noreply, state}
  end

  def handle_info(:start_iteration, %{grid: grid, iteration: iteration} = state) do
    Process.sleep(300)

    create_plan = &@module_prefix.PlanCreator.create_plan/6
    plans = StartIteration.create_plans(iteration, grid, state.objects_state, create_plan)

    # Printer.print_objects(grid, "grid - #{inspect(self())}")
    # Printer.print_plans(plans, "self - #{inspect(self())}")
    # IO.inspect {"self", plans}

    # Printer.print_objects(grid, :start_iteration)
    # Printer.write_to_file(grid, "grid_#{iteration}")
    # Printer.print_plans(plans)
    # IO.inspect(state.objects_state)
    distribute_plans(state, plans)

    state = Map.merge(state, %{plans: plans, processed_nieghbors: 0})
    {:noreply, state}
  end

  # For now abandon 'Alternative' from discarded plans in remote plans (no use of it in the
  # current examples). Currently, there is also no use of :remote_signal and :remote_cell_contents
  # states. Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  def handle_info({:remote_plans, pid, tensor}, state) do
    %{
      grid: grid,
      neighbors: neighbors,
      neighbors_count: neighbors_count, 
      objects_state: objects_state,
      plans: plans,
      processed_neighbors: processed_neighbors
    } = state

    {x_size, y_size, _z_size} = Nx.shape(plans)
    
    direction = neighbors[pid]

    location = get_put_slice_start(x_size, y_size, direction)
    plans = Nx.put_slice(plans, location, tensor)

    if neighbors_count == processed_neighbors + 1 do
      is_update_valid? = &@module_prefix.PlanResolver.is_update_valid?/2
      apply_action = &@module_prefix.PlanResolver.apply_action/3

      {updated_grid, accepted_plans, objects_state} =
        RemotePlans.process_plans(
          grid,
          plans,
          objects_state,
          is_update_valid?,
          apply_action
        )

      # distribute_consequences(state, updated_grid, plans, accepted_plans)

      # IO.inspect(accepted_plans)
      # Printer.print_objects(updated_grid, :remote_plans)

      state = Map.merge(state, %{
        grid: updated_grid, 
        objects_state: objects_state, 
        processed_neighbors: 0
      })

      {:noreply, state}
    else
      {:noreply, %{state | plans: plans, processed_neighbors: processed_neighbors + 1}}
    end
  end

  def handle_info({:remote_consequences, pid, updated_grid, plans, accepted_plans}, %{grid: grid} = state) do
    apply_consequence = &@module_prefix.PlanResolver.apply_consequence/3

    {updated_grid, objects_state} =
      RemoteConsequences.apply_consequences(
        grid,
        state.objects_state,
        plans,
        accepted_plans,
        apply_consequence
      )

    # TODO in the future could get object state as well ?
    generate_signal = &@module_prefix.Cell.generate_signal/1
    signal_update = RemoteConsequences.calculate_signal_updates(updated_grid, generate_signal)

    # distribute_signal(signal_update)

    # Printer.print_objects(updated_grid, :remote_consequences)

    {:noreply, %{state | grid: updated_grid, objects_state: objects_state}}
    # {:noreply, state}
  end

  def handle_info({:remote_signal, signal_update}, state) do
    %{grid: grid, iteration: iteration} = state

    # TODO should signal factor depend on object state?
    signal_factor = &@module_prefix.Cell.signal_factor/1
    updated_grid = RemoteSignal.apply_signal_update(grid, signal_update, signal_factor)

    # Printer.print_objects(updated_grid, :remote_signal)

    start_next_iteration()
    {:noreply, %{state | grid: updated_grid, iteration: iteration + 1}}
  end

  # sends each plan to worker managing cells affected by this plan
  defp distribute_plans(%{neighbors: neighbors}, plans) do
    {x_size, y_size, _z_size} = Nx.shape(plans)

    tensors = [plans]
    send_to_neighbors(neighbors, x_size, y_size, :remote_plans, tensors)
  end

  # Sends each consequence to worker managing cells affected by this plan consequence.
  defp distribute_consequences(%{neighbors: neighbors}, updated_grid, plans, accepted_plans) do
    {x_size, y_size, _z_size} = Nx.shape(plans)

    tensors = [updated_grid, plans, accepted_plans]
    send_to_neighbors(neighbors, x_size, y_size, :remote_consequences, tensors)
  end

  # Sends each signal to worker managing cells affected by this signal.
  defp distribute_signal(signal_update) do
    send(self(), {:remote_signal, signal_update})
  end

  # Starts the next iteration by sending message.
  defp start_next_iteration() do
    send(self(), :start_iteration)
  end

  defp send_to_neighbors(neighbors, x_size, y_size, message_atom, tensors) do
    neighbors
    |> Map.keys()
    |> Enum.filter(fn key -> key in @directions end)
    |> Enum.each(fn direction -> 
      start = get_slice_start(x_size, y_size, direction)
      length = get_slice_length(x_size, y_size, direction)

      message =
        tensors
        |> Enum.map(fn tensor -> Nx.slice(tensor, start, length) end)
        |> then(fn tensors -> [message_atom, self()] ++ tensors end)
        |> List.to_tuple()

      send(neighbors[direction], message)
    end)
  end

  defp get_slice_start(_x_size, _y_size, @dir_top), do: [1, 1, 0]
  defp get_slice_start(_x_size, y_size, @dir_top_right), do: [1, y_size - 2, 0]
  defp get_slice_start(_x_size, y_size, @dir_right), do: [1, y_size - 2, 0]
  defp get_slice_start(x_size, y_size, @dir_bottom_right), do: [x_size - 2, y_size - 2, 0]
  defp get_slice_start(x_size, _y_size, @dir_bottom), do: [x_size - 2, 1, 0]
  defp get_slice_start(x_size, _y_size, @dir_bottom_left), do: [x_size - 2, 1, 0]
  defp get_slice_start(_x_size, _y_size, @dir_left), do: [1, 1, 0]
  defp get_slice_start(_x_size, _y_size, @dir_top_left), do: [1, 1, 0]

  defp get_slice_length(_x_size, y_size, @dir_top), do: [1, y_size - 2, 3]
  defp get_slice_length(_x_size, _y_size, @dir_top_right), do: [1, 1, 3]
  defp get_slice_length(x_size, _y_size, @dir_right), do: [x_size - 2, 1, 3]
  defp get_slice_length(_x_size, _y_size, @dir_bottom_right), do: [1, 1, 3]
  defp get_slice_length(_x_size, y_size, @dir_bottom), do: [1, y_size - 2, 3]
  defp get_slice_length(_x_size, _y_size, @dir_bottom_left), do: [1, 1, 3]
  defp get_slice_length(x_size, _y_size, @dir_left), do: [x_size - 2, 1, 3]
  defp get_slice_length(_x_size, _y_size, @dir_top_left), do: [1, 1, 3]

  defp get_put_slice_start(_x_size, _y_size, @dir_top), do: [0, 1, 0]
  defp get_put_slice_start(_x_size, y_size, @dir_top_right), do: [0, y_size - 1, 0]
  defp get_put_slice_start(_x_size, y_size, @dir_right), do: [1, y_size - 1, 0]
  defp get_put_slice_start(x_size, y_size, @dir_bottom_right), do: [x_size - 1, y_size - 1, 0]
  defp get_put_slice_start(x_size, _y_size, @dir_bottom), do: [x_size - 1, 1, 0]
  defp get_put_slice_start(x_size, _y_size, @dir_bottom_left), do: [x_size - 1, 0, 0]
  defp get_put_slice_start(_x_size, _y_size, @dir_left), do: [1, 0, 0]
  defp get_put_slice_start(_x_size, _y_size, @dir_top_left), do: [0, 0, 0]
end
