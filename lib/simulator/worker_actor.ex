defmodule Simulator.WorkerActor do
  @moduledoc """
  GenServer responsible for simulating one shard.
  TODO update because there is no start_iteration anymore
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
    state = %{grid: grid, iteration: 0, location: location, objects_state: objects_state}

    Printer.create_directory(location)

    {:ok, state}
  end

  @impl true
  def handle_info({:neighbors, neighbors}, state) do
    state = Map.merge(state, %{
      neighbors: neighbors, 
      neighbors_count: neighbors |> map_size() |> div(2),
      processed_neighbors: 0
      })

    {:noreply, state}
  end

  def handle_info(:start, state), do: start_new_iteration(state)

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

    location = put_slice_start(plans, direction)
    plans = Nx.put_slice(plans, location, tensor)

    if neighbors_count == processed_neighbors + 1 do
      is_update_valid? = &@module_prefix.PlanResolver.is_update_valid?/2
      apply_action = &@module_prefix.PlanResolver.apply_action/3

      Printer.print_plans(plans, "plans - " <> inspect(state.location))

      {updated_grid, accepted_plans, objects_state} =
        RemotePlans.process_plans(
          grid,
          plans,
          objects_state,
          is_update_valid?,
          apply_action
        )

      distribute_consequences(state, updated_grid, objects_state, accepted_plans)

      Printer.print_objects(updated_grid, "self objects - " <> inspect(state.location))
      Printer.print_accepted_plans(accepted_plans, "self accepted - " <> inspect(state.location))

      state = Map.merge(state, %{
        accepted_plans: accepted_plans,
        grid: updated_grid,
        objects_state: objects_state, 
        processed_neighbors: 0
      })

      {:noreply, state}
    else
      {:noreply, %{state | plans: plans, processed_neighbors: processed_neighbors + 1}}
    end
  end

  def handle_info({:remote_consequences, pid, updated_grid, update_objects_state, new_accepted_plans}, state) do
    %{
      accepted_plans: accepted_plans,
      grid: grid,
      neighbors: neighbors,
      neighbors_count: neighbors_count, 
      objects_state: objects_state,
      plans: plans,
      processed_neighbors: processed_neighbors
    } = state

    {x_size, y_size, _z_size} = Nx.shape(updated_grid)
    
    direction = neighbors[pid]

    Printer.print_objects(updated_grid, "remote objects - " <> inspect(state.location) <> " - #{direction}")
    Printer.print_objects_state(update_objects_state, "remote objects state - " <> inspect(state.location) <> " - #{direction}")
    Printer.print_accepted_plans(new_accepted_plans, "remote accepted - " <> inspect(state.location) <> " - #{direction}")

    location_grid = put_slice_start(grid, direction)
    grid = Nx.put_slice(grid, location_grid, updated_grid)

    location_objects_state = put_slice_start(objects_state, direction)
    objects_state = Nx.put_slice(objects_state, location_objects_state, update_objects_state)

    location_plans = slice_start_plans(accepted_plans, direction)
    accepted_plans = put_at(accepted_plans, location_plans, new_accepted_plans)

    if neighbors_count == processed_neighbors + 1 do
      apply_consequence = &@module_prefix.PlanResolver.apply_consequence/3

      Printer.print_objects(grid, "full objects - " <> inspect(state.location))
      Printer.print_objects_state(objects_state, "full objects state - " <> inspect(state.location))
      Printer.print_accepted_plans(accepted_plans, "full accepted - " <> inspect(state.location))

      {updated_grid, objects_state} =
        RemoteConsequences.apply_consequences(
          grid,
          objects_state,
          plans,
          accepted_plans,
          apply_consequence
        )

      Printer.print_objects(updated_grid, "self objects end - " <> inspect(state.location))
      Printer.print_objects_state(objects_state, "self objects state end - " <> inspect(state.location))
      
      # TODO in the future could get object state as well ?
      generate_signal = &@module_prefix.Cell.generate_signal/1
      signal_update = RemoteConsequences.calculate_signal_updates(updated_grid, generate_signal)

      distribute_signal(state, signal_update)

      state = Map.merge(state, %{
        grid: updated_grid,
        objects_state: objects_state, 
        processed_neighbors: 0,
        signal_update: signal_update
      })

      {:noreply, state}
    else
      state = Map.merge(state, %{
        accepted_plans: accepted_plans, 
        grid: grid, 
        processed_neighbors: processed_neighbors + 1
      })

      {:noreply, state}
    end
  end

  def handle_info({:remote_signal, pid, remote_signal_update}, state) do
    %{
      grid: grid,
      iteration: iteration,
      neighbors: neighbors,
      neighbors_count: neighbors_count, 
      processed_neighbors: processed_neighbors,
      signal_update: signal_update
    } = state

    {x_size, y_size, _z_size} = Nx.shape(signal_update)
    
    direction = neighbors[pid]

    location = put_slice_start(signal_update, direction)
    signal_update = Nx.put_slice(signal_update, location, remote_signal_update)

    if neighbors_count == processed_neighbors + 1 do
      # TODO should signal factor depend on object state?
      signal_factor = &@module_prefix.Cell.signal_factor/1
      updated_grid = RemoteSignal.apply_signal_update(grid, signal_update, signal_factor)

      state = Map.merge(state, %{
        grid: updated_grid,
        iteration: iteration + 1
      })

      start_new_iteration(state)
    else
      state = Map.merge(state, %{
        processed_neighbors: processed_neighbors + 1,
        signal_update: signal_update
      })

      {:noreply, state}
    end
  end

  defp start_new_iteration(%{iteration: iteration} = state) when iteration >= @max_iterations do
    Printer.write_to_file(state)
    {:stop, :normal, state}
  end

  defp start_new_iteration(state) do
    Printer.write_to_file(state)

    %{grid: grid, iteration: iteration, objects_state: objects_state} = state

    create_plan = &@module_prefix.PlanCreator.create_plan/6
    plans = StartIteration.create_plans(iteration, grid, objects_state, create_plan)

    distribute_plans(state, plans)

    state = Map.merge(state, %{plans: plans, processed_nieghbors: 0})
    {:noreply, state}
  end

  # sends each plan to worker managing cells affected by this plan
  defp distribute_plans(%{neighbors: neighbors}, plans) do
    tensors = [{plans, &slice_start/2, &slice_length/2}]

    send_to_neighbors(neighbors, :remote_plans, tensors)
  end

  # Sends each consequence to worker managing cells affected by this plan consequence.
  defp distribute_consequences(%{neighbors: neighbors}, updated_grid, objects_state, accepted_plans) do
    tensors = [
      {updated_grid, &slice_start/2, &slice_length/2},
      {objects_state, &slice_start/2, &slice_length/2},
      {accepted_plans, &slice_start_plans/2, &slice_length_plans/2}
    ]

    send_to_neighbors(neighbors, :remote_consequences, tensors)
  end

  # Sends each signal to worker managing cells affected by this signal.
  defp distribute_signal(%{neighbors: neighbors}, signal_update) do
    tensors = [{signal_update, &slice_start/2, &slice_length/2}]
    send_to_neighbors(neighbors, :remote_signal, tensors)
  end

  defp send_to_neighbors(neighbors, message_atom, tensors) do
    neighbors
    |> Map.keys()
    |> Enum.filter(fn key -> key in @directions end)
    |> Enum.each(fn direction -> 
      message =
        tensors
        |> Enum.map(fn {tensor, start_fun, length_fun} -> 
          start = start_fun.(tensor, direction)
          length = length_fun.(tensor, direction)

          Nx.slice(tensor, start, length) 
        end)
        |> then(fn tensors -> [message_atom, self()] ++ tensors end)
        |> List.to_tuple()

      send(neighbors[direction], message)
    end)
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

  # it requires information that @rejected = 0 and @accepted = 1
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
    |> then(fn [x_size, y_size | rest] -> rest end)
  end
end
