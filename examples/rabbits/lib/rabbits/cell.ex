defmodule Rabbits.Cell do
  use Rabbits.Constants
  use Simulator.Cell

  import Nx.Defn

    @impl true
    defn signal_generators() do
      Nx.tensor([
        [@rabbit, @rabbit_signal],
        [@lettuce, @lettuce_signal]
      ])
    end

    @impl true
    defn signal_factors() do
      Nx.tensor([
        [@empty, 1]
      ])
    end
end
