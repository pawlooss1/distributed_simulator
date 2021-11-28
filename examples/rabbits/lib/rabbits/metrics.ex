defmodule Rabbits.Metrics do
  use Rabbits.Constants
  use Simulator.Metrics

  import Nx.Defn

  @impl true
  def calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iterations) do
    # metrics store 3 values: rabbits alive now, sum of rabbits alive in all previous steps, average alive rabbits in any step
    iterations = max(iterations, 1)
    {x, y, _z} = Nx.shape(old_grid)
    alive_rabbits =
      old_grid[[0..x-1, 0..y-1, 0]]
      |> Nx.equal(@rabbit)
      |> Nx.sum()
      |> Nx.add(Nx.tensor([0], type: Nx.type(metrics))) # cast to metrics type - otherwise error for put_slice with s64 and u64
    sum_alive_rabbits = Nx.add(metrics[0], alive_rabbits)
    avg_alive_rabbits = Nx.divide(metrics[1], iterations) |> Nx.reshape({1})
    metrics = Nx.put_slice(metrics, [0], alive_rabbits)
    metrics = Nx.put_slice(metrics, [1], sum_alive_rabbits)
    metrics = Nx.put_slice(metrics, [2], avg_alive_rabbits)
    metrics
  end
end
