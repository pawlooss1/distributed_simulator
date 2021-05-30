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
    grid = make_grid()

    grid = populate_evenly grid
#    signal = initialize_signal Map.keys(cells_by_coords)
#
    pid = spawn(WorkerActor, :listen, [grid])
#    write_to_file(grid, signal, "grid_0")
#
    send(pid, {:start_iteration, 1})
    :ok
  end

  defp make_grid() do
    {x_size, y_size} = get_size()
    cells = for k_x <- 1..x_size, k_y <- 1..y_size, into: %{}, do: {{k_x, k_y}, :empty}
    cells
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

    grid
    |> populate(mocks_positions)
    |> map_to_list()
    |> Nx.tensor()
  end

  # adds `:mock` objects on given coordinates
  defp populate(grid, []),
    do: grid
  defp populate(grid, [coord | coords]),
    do: populate(%{grid | coord => :mock}, coords)

  defp map_to_list(map) do
    {x_size, y_size} = get_size()
    cells =
          for x <- 1..x_size, do: (
            for y <- 1..y_size, do: {x, y})
    cells
    |> Enum.map(fn row -> Enum.map(row, fn cell -> as_list(cell, map) end) end)
  end

  defp as_list(cell, map) do
    case map[cell] do
      :empty -> for _ <- 1..9, do: 0
      :mock -> [0, 0, 0, 0, 1, 0, 0, 0, 0]
    end
  end

  defp pretty_print(tensor) do
    {x_size, y_size, _} = Nx.shape(tensor)
    as_string =
      get_template(x_size, y_size)
      |> Enum.map(fn x ->
        Enum.map(x, fn xx ->
          Enum.map(xx, fn y ->
            Enum.map(y, fn yy -> Nx.to_scalar(tensor[elem(yy, 0)][elem(yy, 1)][elem(yy, 2)]) end)
          end)
        end)
      end)
      |> Enum.map(fn x ->
        Enum.map(x, fn xx ->
          Enum.map(xx, fn y ->
            Enum.join(y, "")
          end)
        end)
      end)
      |> Enum.map(fn x ->
        Enum.map(x, fn xx ->
          Enum.join(xx, " ")
        end)
      end)
      |> Enum.map(fn x ->
        Enum.join(x, "\n")
      end)
      |> Enum.join("\n\n")

    IO.puts as_string
  end

  defp get_template(x_size, y_size) do
    for x <- 0..(x_size-1), do: (
      for xx <- 0..2, do: (
        for y <- 0..(y_size-1), do: (
          for yy <- 0..2, do: {x, y, xx * 3 + yy})))
  end

  defp get_size,
    do: {Application.fetch_env!(:distributed_simulator, :x_size), Application.fetch_env!(:distributed_simulator, :y_size)}
end
