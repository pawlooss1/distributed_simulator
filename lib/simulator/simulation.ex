defmodule Simulator.Simulation do
  @moduledoc """
  Entry point. Every simulation should call 
  Simulator.Simulation.start/5.
  """

  use Simulator.BaseConstants

  alias Simulator.{Helpers, WorkerActor}

  def start(
        grid,
        objects_state,
        metrics \\ Nx.tensor(0),
        metrics_save_step \\ 5,
        workers_by_dim \\ {2, 3}
      ) do
    grid
    |> split_grid_among_workers(objects_state, workers_by_dim, metrics, metrics_save_step)
    |> Enum.each(fn {location, worker_pid} ->
      IO.inspect({location, worker_pid})
      GenServer.cast({:global, location}, :start)
    end)
  end

  @spec get_next_node(integer, integer, integer, integer) :: any
  def get_next_node(r, c, workers_rows, workers_cols) do
    num_nodes = length(Node.list()) + 1
    worker_idx = workers_cols * (r - 1) + c - 1

    all_workers = workers_cols * workers_rows
    node_idx = div(worker_idx * num_nodes, all_workers)

    [Node.self() | Node.list()] |> Enum.at(node_idx)
  end

  def split_grid_among_workers(grid, state, {workers_x, workers_y}, metrics, metrics_save_step) do
    {bigger_grid, bigger_state} = add_margins(grid, state)

    workers =
      for i <- 1..workers_x,
          j <- 1..workers_y,
          do:
            create_worker(
              i,
              j,
              workers_x,
              workers_y,
              bigger_grid,
              bigger_state,
              metrics,
              metrics_save_step
            )

    :timer.sleep(1000)
    workers = Map.new(workers) |> link_workers()

    IO.inspect(workers)
  end

  defp add_margins(grid, state) do
    {x, y, z} = Nx.shape(grid)
    bigger_grid = Nx.broadcast(0, {x + 2, y + 2, z})
    bigger_grid = Nx.put_slice(bigger_grid, [1, 1, 0], grid)

    state_shape = Nx.shape(state) |> put_elem(0, x + 2) |> put_elem(1, y + 2)
    rem_dims_idxs = List.duplicate(0, tuple_size(state_shape) - 2)

    bigger_state =
      0
      |> Nx.broadcast(state_shape)
      |> Nx.put_slice([1, 1 | rem_dims_idxs], state)

    {bigger_grid, bigger_state}
  end

  defp create_worker(x, y, workers_x, workers_y, grid, bigger_state, metrics, metrics_save_step) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    range_x = start_idx(x, x_size, workers_x)..end_idx(x, x_size, workers_x)
    range_y = start_idx(y, y_size, workers_y)..end_idx(y, y_size, workers_y)

    local_grid = grid[[range_x, range_y]]
    local_objects_state = bigger_state[[range_x, range_y]]

    # Printer.print_objects(local_grid, {x, y})
    node = get_next_node(x, y, workers_x, workers_y)

    pid =
      Node.spawn(
        node,
        fn ->
          {:ok, pid} =
            GenServer.start(
              WorkerActor,
              [
                grid: local_grid,
                objects_state: local_objects_state,
                location: {x, y},
                metrics: metrics,
                metrics_save_step: metrics_save_step
              ],
              name: {:global, {x, y}}
            )

          ref = Process.monitor(pid)

          # Wait until the process monitored by `ref` is down.
          receive do
            {:DOWN, ^ref, _, _, _} ->
              IO.puts("Process #{inspect(pid)} is down")
          end
        end
      )

    {{x, y}, pid}
  end

  defp link_workers(workers) do
    workers
    |> Enum.each(fn {loc, _pid} ->
      GenServer.cast({:global, loc}, {:neighbors, create_neighbors(loc, workers)})
    end)

    workers
  end

  defp create_neighbors(location, workers) do
    directions_to_locs =
      @directions
      |> Enum.map(fn direction -> {direction, {:global, shift(location, direction)}} end)
      |> Enum.reject(fn {_direction, {:global, loc}} -> workers[loc] == nil end)

    locs_to_directions =
      directions_to_locs
      |> Enum.map(fn {direction, loc} -> {loc, direction} end)

    Map.new(directions_to_locs ++ locs_to_directions)
  end

  defp start_idx(1, dim_size, worker_count), do: 0

  defp start_idx(worker_nr, dim_size, worker_count) do
    div(dim_size, worker_count) * (worker_nr - 1) - 1
  end

  defp end_idx(worker_nr, dim_size, worker_nr), do: dim_size - 1

  defp end_idx(worker_nr, dim_size, worker_count) do
    div(dim_size, worker_count) * worker_nr
  end

  def shift(location, direction) do
    {x, y} = Helpers.shift(location, direction)
    {Nx.to_scalar(x), Nx.to_scalar(y)}
  end
end