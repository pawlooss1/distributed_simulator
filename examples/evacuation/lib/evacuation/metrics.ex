defmodule Evacuation.Metrics do
  use Evacuation.Constants
  use Simulator.Metrics

  import Nx.Defn

  @impl true
  def calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iterations) do
      # metrics store 3 values: cells on fire now, sum of all cells on fire in previous steps, average cells on fire on any step
      iterations = max(iterations, 1)
      {x, y, _z} = Nx.shape(old_grid)
      fire_cells =
        old_grid[[0..x-1, 0..y-1, 0]]
        |> Nx.equal(@fire)
        |> Nx.sum()
        |> Nx.add(Nx.tensor([0], type: Nx.type(metrics))) # cast to metrics type - otherwise error for put_slice with s64 and u64
      sum_fire_cells = Nx.add(metrics[0], fire_cells)
      avg_fire_cells = Nx.divide(metrics[1], iterations) |> Nx.reshape({1})
      metrics = Nx.put_slice(metrics, [0], fire_cells)
      metrics = Nx.put_slice(metrics, [1], sum_fire_cells)
      metrics = Nx.put_slice(metrics, [2], avg_fire_cells)
      metrics
  end
end
