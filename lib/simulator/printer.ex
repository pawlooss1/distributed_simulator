defmodule Simulator.Printer do
  @moduledoc """
  Prints grid in (relatively) readable way.
  """

  # TODO used one
  import Nx.Defn

  @visualization_path "lib/grid_iterations"

  @doc """
  Writes grid as tensor to file. Firstly, it is converted to string.
  """
  def write_to_file(%{grid: grid, iteration: iteration, location: location}) do
    grid_as_string = tensor_to_string(grid)

    get_directory_from_location(location) <> "/grid_#{iteration}.txt"
    |> File.write!(grid_as_string)

    IO.puts("Iteration #{iteration} of worker #{inspect(location)} saved to file")
  end

  @doc """
  Creates directory for visualization of the grid of the worker located in {`x`, `y`}.
  """
  def create_directory(location) do
    unless File.exists?(@visualization_path) do
      File.mkdir!(@visualization_path)
    end

    location
    |> get_directory_from_location()
    |> File.mkdir!()
  end

  @doc """
  Delete all the contents of the directory with files for visualization.
  """
  def clean_grid_iterations() do
    @visualization_path <> "/*"
    |> Path.wildcard()
    |> Enum.each(fn path -> File.rm_rf!(path) end)
  end

  @doc """
  Prints given `grid`.
  """
  def print(grid, phase \\ nil) do
    unless phase == nil, do: IO.inspect(phase)
    IO.puts(tensor_to_string(grid) <> "\n\n")
  end

  @doc """
  Prints only the objects from the given `grid`.
  """
  def print_objects(grid, description \\ nil) do
    {x_size, y_size, _} = Nx.shape(grid)

    string = 
      Nx.to_flat_list(grid)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(9)
      |> Enum.map(fn [object | rest] -> object end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  def print_state(grid, phase \\ nil) do
    unless phase == nil, do: IO.inspect(phase)

    {x_size, y_size} = Nx.shape(grid)

    Nx.to_flat_list(grid)
    |> Enum.map(fn num -> to_string(num) end)
    |> Enum.chunk_every(y_size)
    |> Enum.map(fn line -> Enum.join(line, " ") end)
    |> Enum.join("\n")
    |> IO.puts()
  end

  def print_3d_tensor(tensor, description \\ nil) do
    {x_size, y_size, z_size} = Nx.shape(tensor)

    string = 
      Nx.to_flat_list(tensor)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(z_size * y_size)
      |> Enum.map(fn line ->
        Enum.chunk_every(line, z_size)
        |> Enum.map(fn cell -> Enum.join(cell, " ") end)
        |> Enum.join("\n")
      end)
      |> Enum.join("\n\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  def print_objects_state(objects_state, description \\ nil) do
    {x_size, y_size} = Nx.shape(objects_state)

    string = 
      Nx.to_flat_list(objects_state)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  def print_accepted_plans(accepted_plans, description \\ nil) do
    {x_size, y_size} = Nx.shape(accepted_plans)

    string = 
      Nx.to_flat_list(accepted_plans)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  defp get_directory_from_location({x, y}), do: @visualization_path <> "/#{x}_#{y}"

  # Converts grid as tensor to (relatively) readable string.
  defp tensor_to_string(tensor) do
    {x_size, y_size, _} = Nx.shape(tensor)

    ans =
      [x_size, y_size]
      |> Enum.concat(Nx.to_flat_list(tensor))
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.join(" ")

    ans
  end

  # From
  # [ object top top-right right bottom-right bottom bottom-left left top-left ]

  # to
  # [ top-left    top    top-right
  #   left        object right
  #   bottom-left bottom bottom-right ]
  defnp reconfigure(tensor) do
    {x_size, y_size, _} = Nx.shape(tensor)

    {_i, tensor} =
      while {i = 0, tensor}, Nx.less(i, x_size) do
        {_i, _j, tensor} =
          while {i, j = 0, tensor}, Nx.less(j, y_size) do
            cell = tensor[i][j]

            reconfigured =
              [cell[8], cell[1], cell[2], cell[7], cell[0], cell[3], cell[6], cell[5], cell[4]]
              |> Nx.stack()
              |> Nx.broadcast({1, 1, 9})

            tensor = Nx.put_slice(tensor, [i, j, 0], reconfigured)

            {i, j + 1, tensor}
          end

        {i + 1, tensor}
      end

    tensor
  end

  @doc """
  Returns 4D list with tuples having indices of tensor to print it in such way:

  sss sss
  sos sos
  sss sos

  sss sss
  sos sos
  sss sss

  where s is signal and o is object.
  """
  defp get_template(x_size, y_size) do
    for x <- 0..(x_size - 1),
        do:
          for(
            xx <- 0..2,
            do: for(y <- 0..(y_size - 1), do: for(yy <- 0..2, do: {x, y, xx * 3 + yy}))
          )
  end
end
