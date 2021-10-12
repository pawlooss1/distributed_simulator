defmodule Simulator.Printer do
  @moduledoc """
  Prints grid in (relatively) readable way.
  """
  # TODO used one
  import Nx.Defn

  @doc """
  Writes grid as tensor to file. Firstly, it is converted to string.

  Prints the string as well.
  """
  def write_to_file(grid, file_name) do
    IO.puts("writing")
    grid_as_string = tensor_to_string(grid)
    # IO.inspect(grid_as_string)

    File.write!("lib/grid_iterations/#{file_name}.txt", grid_as_string)
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
  def print_objects(grid, phase \\ nil) do
    unless phase == nil, do: IO.inspect(phase)

    {x_size, y_size, _} = Nx.shape(grid)

    Nx.to_flat_list(grid)
    |> Enum.map(fn num -> to_string(num) end)
    |> Enum.chunk_every(9)
    |> Enum.map(fn [object | rest] -> object end)
    |> Enum.chunk_every(x_size)
    |> Enum.map(fn line -> Enum.join(line, " ") end)
    |> Enum.join("\n")
    |> IO.puts()
  end

  def print_plans(plans) do
    {x_size, y_size, _} = Nx.shape(plans)

    Nx.to_flat_list(plans)
    |> Enum.map(fn num -> to_string(num) end)
    |> Enum.chunk_every(3 * x_size)
    |> Enum.map(fn line ->
      Enum.chunk_every(line, 3)
      |> Enum.map(fn plan -> Enum.join(plan, " ") end)
      |> Enum.join("\n")
    end)
    |> Enum.join("\n\n")
    |> IO.puts()
  end

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
