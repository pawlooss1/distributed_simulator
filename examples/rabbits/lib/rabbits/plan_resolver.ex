defmodule Rabbits.PlanResolver do
  use Rabbits.Constants
  use Simulator.PlanResolver

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn action_mappings() do
    # TODO move po's to consts
    Nx.tensor([
      [0x01_03_00, @rabbit, @move],
      [0x01_03_02, @rabbit, @eat],
      [0x01_00_00, @rabbit, @reproduce],
      [0x01_00_02, @rabbit, @reproduce_eat],
      [0x02_00_00, @lettuce, @identity],
      [0x03_00_01, @empty, @zero_energy],
      [0x05_00_01, @rabbit, @stay]
    ])
  end

  @impl true
  defn map_state_action(objects_state, fun_label) do
    cond do
      fun_label == @identity -> identity(objects_state)
      fun_label == @move -> objects_state - @move_cost
      fun_label == @eat -> objects_state + @lettuce_energy_boost
      fun_label == @reproduce -> @rabbit_reproduction_energy
      fun_label == @reproduce_eat -> @rabbit_reproduction_energy + @lettuce_energy_boost
      fun_label == @zero_energy -> 0
      fun_label == @stay -> objects_state - @stay_cost
      true -> objects_state
    end
  end

  @impl true
  defn consequence_mappings() do
    # TODO move po's to consts
    Nx.tensor([
      [0x01_03_01, @empty, @zero_energy],
      [0x01_00_01, @rabbit, @reproduce]
    ])
  end

  @impl true
  defn map_state_consequence(objects_state, fun_label) do
    cond do
      fun_label == @zero_energy -> 0
      fun_label == @reproduce -> objects_state - @rabbit_reproduction_energy
      true -> objects_state
    end
  end
end
