defmodule RabbitsGenerator do
  def generate_map(width, height, rabbit_chance, lettuce_chance) do
    map =
      1..height
      |> pmap(fn _row -> generate_row(rabbit_chance, lettuce_chance, width) end)
      |> Enum.join("\n")

    output_directory = "examples/rabbits/lib/maps"
    file_name = "map_#{width}x#{height}.txt"

    output_file = "#{output_directory}/#{file_name}"

    File.write(output_file, map)
  end

  def generate_row(rabbit_chance, lettuce_chance, width) do
    1..width
    |> Enum.map(fn _index ->
      selected = :rand.uniform()

      cond do
        selected <= rabbit_chance -> "r"
        selected <= rabbit_chance + lettuce_chance -> "l"
        :otherwise -> "-"
      end
    end)
    |> Enum.join()
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(&Task.await/1)
  end
end
