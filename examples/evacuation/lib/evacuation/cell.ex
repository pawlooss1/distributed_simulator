defmodule Evacuation.Cell do
  @moduledoc false

  @behaviour Simulator.Cell

  import Nx.Defn

  # todo repeated, in future import
  @person 1
  @obstacle 2
  @exit 3
  @fire 4

  @exit_signal 30
  @fire_signal -30

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
