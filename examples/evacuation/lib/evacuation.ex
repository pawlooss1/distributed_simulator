defmodule Evacuation do
  @moduledoc """
  Simulation of the evacuation using DistributedSimulator framework.
  """

  use Evacuation.Constants

  alias Simulator.{Printer, WorkerActor}

  @doc """
  Runs the simulation.
  """
  @spec start() :: :ok
  def start() do
    grid = read_grid("map_1")
    {x, y, _z} = Nx.shape(grid)
    object_data = Nx.broadcast(0, {x, y, 1})

    clean_grid_iterations()

    WorkerActor.start(grid: grid, object_data: object_data)
    Printer.write_to_file(grid, "grid_0")
    :ok
  end

  defp read_grid(file_name) do
    File.read!("lib/maps/#{file_name}.txt")
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
    |> Nx.tensor()
  end

  defp parse_line(line) do
    line
    |> String.graphemes()
    |> Enum.map(fn letter ->
      case letter do
        "-" -> @empty
        "p" -> @person
        "o" -> @obstacle
        "e" -> @exit
        "f" -> @fire
        _ -> raise("#{letter} is an invalid letter in the given evacuation map")
      end
    end)
    |> Enum.map(fn contents -> [contents, 0, 0, 0, 0, 0, 0, 0, 0] end)
  end

  defp clean_grid_iterations() do
    "lib/grid_iterations/*"
    |> Path.wildcard()
    |> Enum.each(fn path -> File.rm!(path) end)
  end
end
