defmodule Simulator.Evacuation do
  @moduledoc """
  Distributed Simulator implemented using Nx library.
  """

  import Simulator.Evacuation.Printer

  alias Simulator.Evacuation.WorkerActor

  @doc """
  Runs simulation.
  """
  def start() do
    grid =
      make_grid()
      |> populate_evenly()

    pid = spawn(WorkerActor, :listen, [grid])
    write_to_file(grid, "grid_0")

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

    mocks_positions =
      for xIndex <- 1..mocks_by_dimension,
          yIndex <- 1..mocks_by_dimension,
          do: {trunc(xIndex * x_unit), trunc(yIndex * y_unit)}

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
    cells = for x <- 1..x_size, do: for(y <- 1..y_size, do: {x, y})

    cells
    |> Enum.map(fn row -> Enum.map(row, fn cell -> as_list(cell, map) end) end)
  end

  defp as_list(cell, map) do
    case map[cell] do
      :empty -> for _ <- 1..9, do: 0
      :mock -> [1, 0, 0, 0, 0, 0, 0, 0, 0]
    end
  end

  defp get_size,
    do:
      {Application.fetch_env!(:distributed_simulator, :x_size),
       Application.fetch_env!(:distributed_simulator, :y_size)}
end
