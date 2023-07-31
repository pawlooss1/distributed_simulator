defmodule Rabbits do
  @moduledoc """
  Simulation of the Rabbits using DistributedSimulator framework.
  """

  use Rabbits.Constants

  alias Simulator.{Printer, Simulation}

  @doc """
  Runs the simulation.
  """
  @spec start() :: :ok
  def start() do
    grid = read_grid("map_4")
    {x, y, _z} = Nx.shape(grid)
    objects_state = Nx.broadcast(@rabbit_start_energy, {x, y})
    metrics = Nx.tensor([0, 0, 0, 0, 0, 0])

    parameters = %{
      grid: grid,
      metrics: metrics,
      metrics_save_step: 4,
      objects_state: objects_state,
      workers_by_dim: {4, 4}
    }

    Simulation.start(parameters)
    :ok
  end

  defp read_grid(file_name) do
    File.read!("lib/maps/#{file_name}.txt")
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
    |> Nx.tensor(type: {:s, 8})
  end

  defp parse_line(line) do
    line
    |> String.graphemes()
    |> Enum.map(fn letter ->
      case letter do
        "-" -> @empty
        "r" -> @rabbit
        "l" -> @lettuce
        _ -> raise("#{letter} is an invalid letter in the given Rabbits map")
      end
    end)
    |> Enum.map(fn contents -> [contents, 0, 0, 0, 0, 0, 0, 0, 0] end)
  end
end
