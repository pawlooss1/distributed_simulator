defmodule Simulator.Printer do
  @moduledoc """
  Prints grid in (relatively) readable way.
  """

  # TODO used one
  import Nx.Defn

  @visualization_path "lib/grid_iterations"
  @metrics_path "metrics"

  @doc """
  Writes grid as tensor to file. Firstly, it is converted to string.
  """
  def write_to_file(%{grid: grid, iteration: iteration, location: location} = state) do
    grid_as_string = tensor_to_string(grid)

    (get_worker_visualization_path(location) <> "/grid_#{iteration}.txt")
    |> File.write!(grid_as_string)

    if rem(iteration, state.metrics_save_step) == 0 do
      IO.puts("saving metrics")

      data =
        state.metrics
        |> Nx.to_flat_list()
        |> Enum.map(fn num -> to_string(num) end)
        |> Enum.join(" ")

      File.write!(get_worker_metrics_path(location), "#{iteration} #{data}\n", [:append])
    end

    IO.puts("Iteration #{iteration} of worker #{inspect(location)} saved to file")
  end

  @doc """
  Creates directory for visualization of the grid of the worker located in {`x`, `y`}.
  """
  def create_visualization_directory(location) do
    unless File.exists?(@visualization_path) do
      File.mkdir!(@visualization_path)
    end

    location
    |> get_worker_visualization_path()
    |> File.mkdir!()
  end

  def create_metrics_directory(location) do
    unless File.exists?(@metrics_path) do
      File.mkdir!(@metrics_path)
    end
  end

  @doc """
  Delete all the contents of the directory with files for visualization.
  """
  def clean_grid_iterations() do
    (@visualization_path <> "/*")
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
    {_x_size, y_size, _z_size} = Nx.shape(grid)

    string =
      Nx.to_flat_list(grid)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(9)
      |> Enum.map(fn [object | _rest] -> object end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  def print_state(grid, phase \\ nil) do
    unless phase == nil, do: IO.inspect(phase)

    {_x_size, y_size} = Nx.shape(grid)

    Nx.to_flat_list(grid)
    |> Enum.map(fn num -> to_string(num) end)
    |> Enum.chunk_every(y_size)
    |> Enum.map(fn line -> Enum.join(line, " ") end)
    |> Enum.join("\n")
    |> IO.puts()
  end

  def print_3d_tensor(tensor, description \\ nil) do
    {_x_size, y_size, z_size} = Nx.shape(tensor)

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
    {_x_size, y_size} = Nx.shape(objects_state)

    string =
      Nx.to_flat_list(objects_state)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  def print_accepted_plans(accepted_plans, description \\ nil) do
    {_x_size, y_size} = Nx.shape(accepted_plans)

    string =
      Nx.to_flat_list(accepted_plans)
      |> Enum.map(fn num -> to_string(num) end)
      |> Enum.chunk_every(y_size)
      |> Enum.map(fn line -> Enum.join(line, " ") end)
      |> Enum.join("\n")

    IO.puts(if description == nil, do: string, else: "#{description}\n#{string}\n")
  end

  defp get_worker_visualization_path({x, y}), do: @visualization_path <> "/#{x}_#{y}"

  defp get_worker_metrics_path({x, y}), do: @metrics_path <> "/#{x}_#{y}.txt"

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
end
