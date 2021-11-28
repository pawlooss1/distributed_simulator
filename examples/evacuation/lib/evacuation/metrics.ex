defmodule Evacuation.Metrics do
  use Evacuation.Constants
  use Simulator.Metrics

  import Nx.Defn

    # TODO add default function?
  @impl true
  def calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iterations) do
    metrics
  end
end
