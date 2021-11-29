defmodule Rabbits.Metrics do
  use Rabbits.Constants
  use Simulator.Metrics

  import Nx.Defn

  @impl true
  def calculate_metrics(metrics, old_grid, old_objects_state, grid, objects_state, iterations) do
    # metrics store 6 values: rabbits alive now, sum of rabbits alive in all previous steps, average alive rabbits in any step,
    # and corresponding 3 values for lettuce
    iterations = max(iterations, 1)
    {x, y, _z} = Nx.shape(old_grid)
    alive_rabbits =
      old_grid[[0..x-1, 0..y-1, 0]]
      |> Nx.equal(@rabbit)
      |> Nx.sum()
      |> Nx.add(Nx.tensor([0], type: Nx.type(metrics))) # cast to metrics type - otherwise error for put_slice with s64 and u64
    sum_alive_rabbits = Nx.add(metrics[0], alive_rabbits)
    avg_alive_rabbits = Nx.divide(metrics[1], iterations) |> Nx.reshape({1})

    alive_lettuce =
      old_grid[[0..x-1, 0..y-1, 0]]
      |> Nx.equal(@lettuce)
      |> Nx.sum()
      |> Nx.add(Nx.tensor([0], type: Nx.type(metrics))) # cast to metrics type - otherwise error for put_slice with s64 and u64
    sum_alive_lettuce = Nx.add(metrics[0], alive_lettuce)
    avg_alive_lettuce = Nx.divide(metrics[1], iterations) |> Nx.reshape({1})

    Nx.concatenate([alive_rabbits, sum_alive_rabbits, avg_alive_rabbits, alive_lettuce, sum_alive_lettuce, avg_alive_lettuce])
  end
end
