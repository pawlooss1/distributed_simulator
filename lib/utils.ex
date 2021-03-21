defmodule Utils do
  @moduledoc false

  def writeToFile grid, fileName do
    gridAsString =
      Map.keys(grid)
      |> Enum.group_by(fn {x, _} -> x end)
      |> Enum.map(fn {line, coords} -> {line, Enum.sort(coords)} end)
      |> Enum.map(fn {_, coords} -> Enum.map(coords, fn coord -> objectToChar(grid[coord]) end) end)
      |> Enum.join("\n")

    File.write! "lib/grid_iterations/#{fileName}.txt", gridAsString
  end

  def objectToChar :empty do
    "-"
  end
  def objectToChar :mock do
    "O"
  end

end
