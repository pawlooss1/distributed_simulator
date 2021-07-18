defmodule Simulator.Evacuation do
  @moduledoc """
  Distributed Simulator implemented using Nx library.
  """

  import Simulator.Evacuation.Printer

  alias Simulator.Evacuation.WorkerActor

  @empty 0
  @person 1
  @obstacle 2
  @exit 3
  @fire 4

  @doc """
  Runs simulation.
  """
  def start() do
    grid = read_grid("map_1")

    pid = spawn(WorkerActor, :listen, [grid])
    write_to_file(grid, "grid_0")

    send(pid, {:start_iteration, 1})
    :ok
  end

  defp read_grid(file_name) do
    File.read!("lib/evacuation/maps/#{file_name}.txt")
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
