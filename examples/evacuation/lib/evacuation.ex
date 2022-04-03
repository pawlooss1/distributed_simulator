defmodule Evacuation do
  @moduledoc """
  Simulation of the evacuation using DistributedSimulator framework.
  """

  use Evacuation.Constants

  alias Simulator.{Printer, Simulation}

  @doc """
  Runs the simulation.
  """
  @spec start() :: :ok
  def start() do
    grid = read_grid("map_1")
    {x, y, _z} = Nx.shape(grid)
    objects_state = Nx.broadcast(0, {x, y})
    metrics = Nx.tensor([0,0,0])
    Printer.clean_grid_iterations()

    parameters = %{
      grid: grid,
      metrics: metrics,
      metrics_save_step: 1,
      objects_state: objects_state,
      workers_by_dim: {3, 2}
    }

    Simulation.start(parameters)
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
