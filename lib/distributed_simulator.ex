defmodule DistributedSimulator do
  @moduledoc """
  Distributed Simulator

  ## To start:

     $ iex -S mix
     iex> DistributedSimulator.start()

  ## Look to "grid_0.txt", "grid_1.txt", ..., "grid_5.txt" files in lib/grid_iterations
  """

  import Position
  import Utils

  @directions [:top, :top_right, :right, :bottom_right, :bottom, :bottom_left, :left, :top_left]

  @doc"""
  Runs simulation.
  """
  def start do
    {cells_by_coords, neighbors} = make_grid()
    grid = populate_evenly cells_by_coords
    signal = initialize_signal Map.keys(cells_by_coords)

    pid = spawn(WorkerActor, :listen, [grid, neighbors, signal])
    write_to_file(grid, signal, "grid_0")

    send(pid, {:start_iteration, 1})
    :ok
  end

  # create grid as Map {coords => cell}, with initially empty cells
  defp make_grid do
    {x_size, y_size} = get_size()

    cells = for k_x <- 1..x_size, k_y <- 1..y_size, into: %{}, do: {{k_x, k_y}, :empty}
    neighbors = cells
                |> Enum.map(fn {coords, _} -> {coords,
                                                (for direction <- @directions, is_valid(shift(coords, direction)), into: %{}, do: {direction, shift(coords, direction)})} end)
                |> Map.new

    {cells, neighbors}
  end

  # checks if given coordinates are within grid bounds
  defp is_valid({x, y}) do
    {x_size, y_size} = get_size()
    x >= 1 and x <= x_size and y >= 1 and y <= y_size
  end

  # adds `:mock` objects distributed evenly on grid
  defp populate_evenly(grid) do
    {x_size, y_size} = get_size()
    mocks_by_dimension = Application.fetch_env!(:distributed_simulator, :mocks_by_dimension)

    x_unit = x_size / (mocks_by_dimension + 1)
    y_unit = y_size / (mocks_by_dimension + 1)

    mocks_positions = for xIndex <- 1..mocks_by_dimension, yIndex <- 1..mocks_by_dimension, do: {trunc(xIndex * x_unit), trunc(yIndex * y_unit)}
    populate(grid, mocks_positions)
  end

  # adds `:mock` objects on given coordinates
  defp populate(grid, []),
    do: grid
  defp populate(grid, [coord | coords]),
    do: populate(%{grid | coord => :mock}, coords)

  # initializes signal map for each coord
  # returns Map {coords => map of signals by direction}
  defp initialize_signal(coords_list) do
    coords_list
    |> Enum.map(fn coords ->
      {coords, Enum.map(@directions, fn direction ->
        {direction, 0} end)} end)
    |> Enum.map(fn {coords, signal_map} ->
      {coords, Map.new(signal_map)} end)
    |> Map.new
  end

  defp get_size,
    do: {Application.fetch_env!(:distributed_simulator, :x_size), Application.fetch_env!(:distributed_simulator, :y_size)}
end
