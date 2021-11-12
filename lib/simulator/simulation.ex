defmodule Simulator.Simulation do
  @moduledoc """
  """
  alias Simulator.{WorkerActor, Printer}

  def start(grid, objects_state, workers_by_dim \\ {2, 3}) do
    grid = split_grid(grid, workers_by_dim)
    WorkerActor.start(grid: grid, objects_state: objects_state)
  end

  def split_grid(grid, {workers_x, workers_y}) do
    {x, y, z} = Nx.shape(grid)
    bigger_grid = Nx.broadcast(0, {x + 2, y + 2, z})
    bigger_grid = Nx.put_slice(bigger_grid, [1, 1, 0], grid)
    Printer.print_objects(bigger_grid, :start_iteration)

    ranges_x = get_ranges(x, workers_x)
    ranges_y = get_ranges(y, workers_y)
    ranges = Enum.zip_with(ranges_x, ranges_y, fn x, y -> [x, y] end)
    IO.inspect(ranges, charlists: :as_lists)
    bigger_grid
  end

  # get overlapping ranges
  def get_ranges(length_left, workers_left, start_idx \\ 1)

  def get_ranges(length_left, 1, start_idx) do
    [(start_idx - 1)..(start_idx + length_left - 1)]
  end

  def get_ranges(length_left, workers_left, start_idx) do
    curr_length = div(length_left, workers_left)
    end_idx = start_idx + curr_length
    [(start_idx - 1)..end_idx | get_ranges(length_left - curr_length, workers_left - 1, end_idx)]
  end
end
