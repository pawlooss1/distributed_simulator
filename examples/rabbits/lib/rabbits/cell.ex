defmodule Rabbits.Cell do
  use Rabbits.Constants
  use Simulator.Cell

  import Nx.Defn

  @impl true
  defn generate_signal(object) do
    cond do
      Nx.equal(object, @rabbit) -> @rabbit_signal
      Nx.equal(object, @lettuce) -> @lettuce_signal
      true -> 0
    end
  end

  @impl true
  defn signal_factor(object) do
    1
  end
end
