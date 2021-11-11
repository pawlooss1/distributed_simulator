defmodule Simulator.Simulation do
  @moduledoc """
  """
  alias Simulator.WorkerActor

  def start(grid, objects_state, workers_by_dim \\ {2, 3}) do
    # WorkerActor.start(grid: grid, objects_state: objects_state)
    split_grid(grid, workers_by_dim)
  end

  def split_grid(grid, {workers_x, workers_y}) do
    {x, y, _z} = Nx.shape(grid)
    ranges_x = get_ranges(x, workers_x)
    ranges_y = get_ranges(y, workers_y)
    IO.inspect(ranges_x, charlists: :as_lists)
    IO.inspect(ranges_y, charlists: :as_lists)
    ranges = Enum.zip_with(ranges_x, ranges_y, fn x, y -> [x, y] end)
    IO.inspect(ranges, charlists: :as_lists)
  end

  def get_ranges(length_left, workers_left, last_idx \\ 0)

  def get_ranges(length_left, 1, last_idx) do
    [last_idx..(last_idx + length_left - 1)]
  end

  def get_ranges(length_left, workers_left, last_idx) do
    curr_length = div(length_left, workers_left)
    next_idx = last_idx + curr_length
    [last_idx..(next_idx - 1) | get_ranges(length_left - curr_length, workers_left - 1, next_idx)]
  end
end
