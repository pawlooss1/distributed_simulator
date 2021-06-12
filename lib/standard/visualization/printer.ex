defmodule Simulator.Standard.Printer do
  @moduledoc false

  @signal_multiplier 30

  def write_to_file grid, signal, file_name do
    grid_as_string = to_string grid, signal
    IO.puts grid_as_string <> "\n"
    File.write!("lib/standard/grid_iterations/#{file_name}.txt", grid_as_string)
  end

  def to_string grid, signal do
    Map.keys(grid)
    |> Enum.group_by(fn {x, _} -> x end)
    |> Enum.map(fn {_line, coords} -> Enum.sort(coords) end)
    |> Enum.map(fn row -> Enum.map(row, &(cell_to_string(&1, grid, signal))) end)
    |> Enum.flat_map(fn row -> to_three_rows row end)
    |> Enum.map(&(Enum.join(&1)))
    |> Enum.join("\n")
  end

  def cell_to_string coords, grid, signal do
    case grid[coords] do
      :mock -> ["XXX ", "XXX ", "XXX "]
      _     ->
        cell_signal = signal[coords]
        [
          "#{trunc(@signal_multiplier*cell_signal[:top_left])}#{trunc(@signal_multiplier*cell_signal[:top])}#{trunc(@signal_multiplier*cell_signal[:top_right])} ",
          "#{trunc(@signal_multiplier*cell_signal[:left])}0#{trunc(@signal_multiplier*cell_signal[:right])} ",
          "#{trunc(@signal_multiplier*cell_signal[:bottom_left])}#{trunc(@signal_multiplier*cell_signal[:bottom])}#{trunc(@signal_multiplier*cell_signal[:bottom_right])} "
        ]
    end
  end

  def to_three_rows row do
    row_1 = Enum.map(row, fn [r_1, _r_2, _r_3] -> r_1 end)
    row_2 = Enum.map(row, fn [_r_1, r_2, _r_3] -> r_2 end)
    row_3 = Enum.map(row, fn [_r_1, _r_2, r_3] -> r_3 end)

    [row_1, row_2, row_3, [""]]
  end
end
