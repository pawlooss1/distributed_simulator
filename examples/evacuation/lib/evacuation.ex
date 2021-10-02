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
    grid = read_grid("map_2")

    WorkerActor.start(grid: grid)
    # Printer.write_to_file(grid, "grid_0")
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
end
