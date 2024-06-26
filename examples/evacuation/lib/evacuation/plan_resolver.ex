defmodule Evacuation.PlanResolver do
  use Evacuation.Constants
  use Simulator.PlanResolver

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn action_mappings() do
    # TODO move po's to consts
    Nx.tensor([
      [0x01_02_00, @person, @identity],
      [0x01_02_03, @exit, @identity],
      [0x03_00_00, @fire, @identity],
      [0x03_00_01, @fire, @identity],
      [0x03_00_03, @fire, @identity],
      [0x03_00_04, @fire, @identity]
    ])
  end

  @impl true
  defn map_state_action(objects_state, _fun_label) do
    identity(objects_state)
  end

  @impl true
  defn consequence_mappings() do
    # TODO move po's to consts
    Nx.tensor([
      [0x01_02_01, @empty, @identity]
    ])
  end

  @impl true
  defn map_state_consequence(objects_state, _fun_label) do
    identity(objects_state)
  end
end
