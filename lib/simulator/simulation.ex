defmodule Simulator.Simulation do
  @moduledoc """
  """
  alias Simulator.{WorkerActor, Printer}

  def start(grid, objects_state, workers_by_dim \\ {1, 2}) do
    grid = split_grid(grid, objects_state, workers_by_dim)
    {:ok, pid} = WorkerActor.start(grid: grid, objects_state: objects_state)
    # send(pid, :start_iteration)
  end

  def split_grid(grid, state, {workers_x, workers_y}) do
    {bigger_grid, bigger_state} = add_margins(grid, state)

    workers =
      for i <- 1..workers_x,
          j <- 1..workers_y,
          do: create_worker(i, j, workers_x, workers_y, bigger_grid, bigger_state)

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
      Nx.broadcast(0, state_shape)
      |> Nx.put_slice([1, 1 | rem_dims_idxs], state)

    {bigger_grid, bigger_state}
  end

  defp create_worker(x, y, workers_x, workers_y, grid, bigger_state) do
    {x_size, y_size, _z_szie} = Nx.shape(grid)
    range_x = start_idx(x, x_size, workers_x)..end_idx(x, x_size, workers_x)
    range_y = start_idx(y, y_size, workers_y)..end_idx(y, y_size, workers_y)
    local_grid = grid[[range_x, range_y]]
    local_objects_state = bigger_state[[range_x, range_y]]
    Printer.print_objects(local_grid, {x, y})
    {:ok, pid} = WorkerActor.start(grid: local_grid, objects_state: local_objects_state)

    {{x, y}, pid}
  end

  defp link_workers(workers) do
    workers
  end

  defp start_idx(1, dim_size, worker_count), do: 0

  defp start_idx(worker_nr, dim_size, worker_count) do
    div(dim_size, worker_count) * (worker_nr - 1) - 1
  end

  defp end_idx(worker_nr, dim_size, worker_nr), do: dim_size - 1

  defp end_idx(worker_nr, dim_size, worker_count) do
    div(dim_size, worker_count) * worker_nr
  end
end
