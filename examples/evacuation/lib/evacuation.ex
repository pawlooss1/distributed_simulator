defmodule Evacuation do
  @moduledoc """
  Simulation of the evacuation using DistributedSimulator framework.
  """

  use Evacuation.Constants

  alias Simulator.{Printer, Simulation}

  @doc """
  Runs the simulation.
  """
  @spec start(String.t()) :: :ok
  def start(map_path) do
    grid = read_grid(map_path)
    {x, y, _z} = Nx.shape(grid)
    objects_state = Nx.broadcast(0, {x, y}) |> Nx.as_type(@objects_state_type)
    metrics = Nx.tensor([0,0,0])
    Printer.clean()

    parameters = %{
      grid: grid,
      metrics: metrics,
      metrics_save_step: 10,
      objects_state: objects_state,
      fill_signal_iterations: 0,
      workers_by_dim: Simulation.fetch_workers_numbers()
    }

    Simulation.start(parameters)
  end

  def read_grid(map_path) do
    File.read!(map_path)
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
    |> Nx.tensor(type: @grid_type)
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
