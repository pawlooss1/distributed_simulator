defmodule Evacuation.Cell do
  @behaviour Simulator.Cell

  use Evacuation.Constants

  import Nx.Defn

  @impl true
  defn generate_signal(object) do
    cond do
      Nx.equal(object, @exit) -> @exit_signal
      Nx.equal(object, @fire) -> @fire_signal
      true -> 0
    end
  end

  @impl true
  defn signal_factor(object) do
    cond do
      Nx.equal(object, @obstacle) -> 0
      true -> 1
    end
  end
end
