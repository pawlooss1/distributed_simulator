defmodule DistributedSimulator do
  @moduledoc """
  Documentation for `DistributedSimulator`.
  """

  @doc """
  Distributed Simulator

  ## To start:

      $ iex -S mix
      iex> DistributedSimulator.start()
      :ok
      terminating worker

  ## Look to "grid_0.txt", "grid_1.txt", ..., "grid_5.txt" files in lib/grid_iterations
  """
  import Position
  import Utils

  @directions [:top, :top_right, :right, :bottom_right, :bottom, :bottom_left, :left, :top_left]

  @x_size 12
  @y_size 12

  @mocks_by_dimension 2

  def is_valid {x, y} do
    x >= 1 and x <= @x_size and y >= 1 and y <= @y_size
  end

  def make_grid do
    cells = for k_x <- 1..@x_size, k_y <- 1..@y_size, into: %{}, do: {{k_x, k_y}, :empty}
    neighbors = cells
      |> Enum.map(fn {coords, _} -> {coords,
                         (for direction <- @directions, is_valid(shift(coords, direction)), into: %{}, do: {direction, shift(coords, direction)})} end)
      |> Map.new

    {cells, neighbors}
  end

  def populate grid, [] do
    grid
  end
  def populate grid, [coord | coords] do
    populate %{grid | coord => :mock}, coords
  end

  def populateEvenly grid do
    xUnit = @x_size / (@mocks_by_dimension + 1)
    yUnit = @y_size / (@mocks_by_dimension + 1)

    mocksPositions = for xIndex <- 1..@mocks_by_dimension, yIndex <- 1..@mocks_by_dimension, do: {trunc(xIndex * xUnit), trunc(yIndex * yUnit)}
    populate grid, mocksPositions
  end

  def start do
    {cells, neighbors} = make_grid()
    grid = populateEvenly cells

    pid = spawn WorkerActor, :listen, [grid, neighbors]
    writeToFile grid, "grid_0"

    send pid, {:start_iteration, 1}
    :ok
  end
end
