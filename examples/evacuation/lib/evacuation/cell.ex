defmodule Evacuation.Cell do
  use Evacuation.Constants
  use Simulator.Cell

  import Nx.Defn

  @impl true
  defn signal_generators() do
    Nx.tensor([
      [@exit, @exit_signal],
      [@fire, @fire_signal]
    ])
  end

  @impl true
  defn signal_factors() do
    Nx.tensor([
      [@obstacle, 0]
    ])
  end
end
