defmodule Evacuation.PlanResolver do
  use Evacuation.Constants
  use Simulator.PlanResolver

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn is_update_valid?(action, object) do
    cond do
      both_equal(action, @add_person, object, @empty) -> Nx.tensor(1)
      both_equal(action, @add_person, object, @exit) -> Nx.tensor(1)
      both_equal(action, @add_person, object, @fire) -> Nx.tensor(1)

      both_equal(action, @remove_person, object, @person) -> Nx.tensor(1)

      both_equal(action, @create_fire, object, @empty) -> Nx.tensor(1)
      both_equal(action, @create_fire, object, @person) -> Nx.tensor(1)
      both_equal(action, @create_fire, object, @exit) -> Nx.tensor(1)

      true -> Nx.tensor(0)
    end
  end

  @impl true
  defn apply_action(object, plan, old_state) do
    {new_object, new_state} =
    cond do
      plans_objects_match(plan, @person_move, object, @empty) -> {@person, old_state}
      plans_objects_match(plan, @person_move, object, @exit) -> {@exit, old_state}
      plans_match(plan, @fire_spread) -> {@fire, old_state}
      true -> {object, old_state}
    end
    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  @impl true
  defn apply_consequence(object, plan, old_state) do
    {new_object, new_state} =
    cond do
      plans_objects_match(plan, @person_move, object, @person) -> {@empty, old_state}
      :otherwise ->
        {object, old_state}
    end
    {new_object, Nx.broadcast(new_state, {1, 1})}
  end
end
