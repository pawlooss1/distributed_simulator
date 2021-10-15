defmodule Simulator.Evacuation.Cell do
  @moduledoc false

  import Nx.Defn

  # todo repeated, in future import
  @person 1
  @obstacle 2
  @exit 3
  @fire 4

  # todo add iteration and config as parameters (not basic functionality)
  @exit_signal 30
  @fire_signal -30

  defn generate_signal(object) do
    cond do
      Nx.equal(object, @exit) -> @exit_signal
      Nx.equal(object, @fire) -> @fire_signal
      true -> 0
    end
  end

  defn signal_factor(object) do
    cond do
      Nx.equal(object, @obstacle) -> 0
      true -> 1
    end
  end
end
