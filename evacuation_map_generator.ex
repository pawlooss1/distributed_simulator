defmodule Generator do
def get_random_coords(range_x, range_y, to_choose, chosen) when length(chosen) < to_choose do
  x = Enum.random(range_x)
  y = Enum.random(range_y)

  if {x, y} in chosen do
    get_random_coords(range_x, range_y, to_choose, chosen)
  else
    get_random_coords(range_x, range_y, to_choose, chosen ++ [{x, y}])
  end
end

def get_random_coords(_range_x, _range_y, _to_choose, chosen), do: chosen

def generate_cell(person_chance, x, y, height, width, exits_coords, flames_coords) do
  cond do
    x in [1, width] or y in [1, height] -> "o"
    {x, y} in exits_coords -> "e"
    {x, y} in flames_coords -> "f"
    :rand.uniform() <= person_chance -> "p"
    :otherwise -> "-"
  end
end

def generate_row(person_chance, y, height, width, exits_coords, flames_coords) do
  1..width
  |> Enum.map(fn x ->
    generate_cell(person_chance, x, y, height, width, exits_coords, flames_coords)
  end)
  |> Enum.join("")
end

def generate_map(width, height, exits, flames, person_chance) do
  # [width, height, exits, flames] =
  #   ["width", "height", "exits", "flames"]
  #   |> Enum.map(&IO.gets/1)
  #   |> Enum.map(&String.trim/1)
  #   |> Enum.map(&String.to_integer/1)

  # person_chance =
  #   "person chance"
  #   |> IO.gets()
  #   |> String.trim()
  #   |> String.to_float()

  range_x = 2..(width - 1)
  range_y = 2..(height - 1)

  exits_coords = get_random_coords(range_x, range_y, exits, [])

  flames_coords =
    get_random_coords(range_x, range_y, exits + flames, exits_coords)
    |> Enum.slice((exits - 1)..(exits + flames - 1))

  map =
    1..height
    |> Enum.map(fn y ->
      generate_row(person_chance, y, height, width, exits_coords, flames_coords)
    end)
    |> Enum.join("\n")

  output_directory = "examples/evacuation/lib/maps" #IO.gets("output directory") |> String.trim()
  file_name = "map_#{width}x#{height}.txt" # IO.gets("file name") |> String.trim()

  output_file = "#{output_directory}/#{file_name}"

  File.write(output_file, map)
end
end
