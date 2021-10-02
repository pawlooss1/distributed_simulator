defmodule Simulator.Evacuation.Printer do
  @moduledoc """
  Prints grid in (relatively) readable way.
  """

  import Nx.Defn

  @doc """
  Writes grid as tensor to file. Firstly, it is converted to string.

  Prints the string as well.
  """
  def write_to_file(grid, file_name) do
    IO.puts("writing")
    grid_as_string = tensor_to_string(grid)
    File.write!("lib/evacuation/grid_iterations/#{file_name}.txt", grid_as_string)
  end

  @doc """
  Prints given `tensor`.
  """
  def print(grid) do
    IO.puts(tensor_to_string(grid) <> "\n\n")
  end

  # Converts grid as tensor to (relatively) readable string.
  defp tensor_to_string(tensor) do
    ans =
      Nx.to_flat_list(tensor)
      |> Enum.map(fn num -> to_string(num) end)
      #          |> Enum.chunk_every() # todo is it needed?
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

            tensor = Nx.put_slice(tensor, reconfigured, [i, j, 0])

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
