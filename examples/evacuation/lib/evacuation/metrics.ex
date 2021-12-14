defmodule Evacuation.Metrics do
  use Evacuation.Constants
  use Simulator.Metrics

  import Nx.Defn

  @impl true
  def calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iterations) do
      iterations = max(iterations, 1)
      {x, y, _z} = Nx.shape(old_grid)
      fire_cells =
        old_grid[[0..x-1, 0..y-1, 0]]
        |> Nx.equal(@fire)
        |> Nx.sum()
        |> Nx.add(Nx.tensor([0], type: Nx.type(metrics)))
      sum_fire_cells = Nx.add(metrics[0], fire_cells)
      avg_fire_cells = Nx.divide(metrics[1], iterations) |> Nx.reshape({1})
      Nx.concatenate([fire_cells, sum_fire_cells, avg_fire_cells])
  end
end
