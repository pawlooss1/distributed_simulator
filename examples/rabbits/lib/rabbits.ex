defmodule Rabbits do
  @moduledoc """
  Simulation of the Rabbits using DistributedSimulator framework.
  """

  use Rabbits.Constants

  alias Simulator.{Printer, Simulation}

  @doc """
  Runs the simulation.
  """
  @spec start(String.t()) :: :ok
  def start(map_path) do
    grid = read_grid(map_path)
    {x, y, _z} = Nx.shape(grid)
    objects_state = Nx.broadcast(@rabbit_start_energy, {x, y}) # TODO sprawdzic czy to nie jest zle
    metrics = Nx.tensor([0, 0, 0, 0, 0, 0])
    Printer.clean()

    parameters = %{
      grid: grid,
      metrics: metrics,
      metrics_save_step: 4,
      objects_state: objects_state,
      fill_signal_iterations: 0,
      workers_by_dim: Simulation.fetch_workers_numbers()
    }

    Simulation.start(parameters)
  end

  defp read_grid(map_path) do
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
        "r" -> @rabbit
        "l" -> @lettuce
        _ -> raise("#{letter} is an invalid letter in the given Rabbits map")
      end
    end)
    |> Enum.map(fn contents -> [contents, 0, 0, 0, 0, 0, 0, 0, 0] end)
  end
end
