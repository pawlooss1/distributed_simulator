defmodule Simulator.Simulation do
  @moduledoc """
  Entry point of the simulation. Every simulation should call Simulator.Simulation.start/5.
  """

  use Simulator.BaseConstants

  alias Simulator.{Helpers, WorkerActor}

  @typedoc """
  Parameters needed to initialize a simulation.

  ## Fields

    * `grid` - Initial grid as 3D tensor.
    * `metrics` - Initial metrics as 3D tensor.
    * `metrics_save_step` - Number of iterations between saving metrics.
    * `objects_state` - Initial state of objects in the grid (Nx tensor). At least two dimensions.
    * `workers_by_dim` - Number of workers in both dimensions (grid has to be rectangular).

  """
  @type simulation_params_t :: %{
          grid: Nx.t(),
          metrics: Nx.t(),
          metrics_save_step: pos_integer(),
          objects_state: Nx.t(),
          workers_by_dim: {pos_integer(), pos_integer()}
        }

  @spec start(simulation_params_t()) :: :ok
  def start(params) do
    params
    |> extend_grid()
    |> split_grid_among_workers()
    |> link_workers()
    |> start_workers()
  end

  defp extend_grid(%{grid: grid, objects_state: objects_state} = params) do
    {x, y, z} = Nx.shape(grid)

    extended_grid =
      0
      |> Nx.broadcast({x + @margin_size * 2, y + @margin_size * 2, z})
      |> Nx.put_slice([@margin_size, @margin_size, 0], grid)

    objects_state_shape =
      objects_state
      |> Nx.shape()
      |> put_elem(0, x + @margin_size * 2)
      |> put_elem(1, y + @margin_size * 2)

    remaining_dimensions_indices = List.duplicate(0, tuple_size(objects_state_shape) - 2)

    extended_objects_state =
      0
      |> Nx.broadcast(objects_state_shape)
      |> Nx.put_slice(
        [@margin_size, @margin_size | remaining_dimensions_indices],
        objects_state
      )

    Map.merge(params, %{grid: extended_grid, objects_state: extended_objects_state})
  end

  defp split_grid_among_workers(params) do
    %{
      grid: grid,
      metrics: metrics,
      metrics_save_step: metrics_save_step,
      objects_state: objects_state,
      workers_by_dim: {workers_x, workers_y} = workers_by_dim
    } = params

    for x <- 1..workers_x, y <- 1..workers_y do
      location = {x, y}

      {grid_fragment, state_fragment} = split_grid(grid, objects_state, location, workers_by_dim)

      initial_state = [
        grid: grid_fragment,
        location: location,
        objects_state: state_fragment,
        metrics: metrics,
        metrics_save_step: metrics_save_step
      ]

      pid =
        location
        |> get_node(workers_by_dim)
        |> Node.spawn(fn -> spawn_worker(location, initial_state) end)

      {location, pid}
    end
    |> Map.new()
  end

  defp split_grid(grid, state, {x, y}, {workers_x, workers_y}) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    range_x = start_idx(x, x_size, workers_x)..end_idx(x, x_size, workers_x)
    range_y = start_idx(y, y_size, workers_y)..end_idx(y, y_size, workers_y)

    {grid[[range_x, range_y]], state[[range_x, range_y]]}
  end

  defp start_idx(1, _dimension_size, _worker_count), do: 0

  defp start_idx(worker_num, dimension_size, worker_count) do
    inner_dimension_size = dimension_size - 2 * @margin_size

    inner_size =
      case rem(inner_dimension_size, worker_count) do
        0 -> div(inner_dimension_size, worker_count)
        _ -> div(inner_dimension_size, worker_count) + 1
      end

    inner_size * (worker_num - 1)
  end

  defp end_idx(worker_num, dimension_size, worker_num), do: dimension_size - 1

  defp end_idx(worker_num, dimension_size, worker_count) do
    inner_dimension_size = dimension_size - 2 * @margin_size

    inner_size =
      case rem(inner_dimension_size, worker_count) do
        0 -> div(inner_dimension_size, worker_count)
        _ -> div(inner_dimension_size, worker_count) + 1
      end

    inner_size * worker_num + 2 * @margin_size - 1
  end

  defp get_node({x, y}, {workers_x, workers_y}) do
    num_nodes = length(Node.list()) + 1
    worker_index = workers_y * (x - 1) + y - 1

    all_workers = workers_y * workers_x
    node_index = div(worker_index * num_nodes, all_workers)

    [Node.self() | Node.list()] |> Enum.at(node_index)
  end

  defp spawn_worker(location, initial_state) do
    {:ok, pid} = GenServer.start(WorkerActor, initial_state, name: {:global, location})

    ref = Process.monitor(pid)

    # Wait until the process monitored by `ref` is down.
    receive do
      {:DOWN, ^ref, _, _, _} ->
        IO.puts("Process #{inspect(pid)} is down")
    end
  end

  defp link_workers(workers) do
    Enum.each(workers, fn {loc, _pid} ->
      GenServer.cast({:global, loc}, {:neighbors, create_neighbors(loc, workers)})
    end)

    workers
  end

  defp create_neighbors(location, workers) do
    directions_to_locations =
      @directions
      |> Enum.map(fn direction -> {direction, {:global, shift(location, direction)}} end)
      |> Enum.reject(fn {_direction, {:global, location}} -> workers[location] == nil end)

    locations_to_directions =
      directions_to_locations
      |> Enum.map(fn {direction, location} -> {location, direction} end)

    Map.new(directions_to_locations ++ locations_to_directions)
  end

  defp start_workers(workers) do
    Enum.each(workers, fn {location, worker_pid} ->
      IO.inspect({location, worker_pid})
      GenServer.cast({:global, location}, :start)
    end)
  end

  defp shift(location, direction) do
    {x, y} = Helpers.shift(location, direction)
    {Nx.to_number(x), Nx.to_number(y)}
  end
end
