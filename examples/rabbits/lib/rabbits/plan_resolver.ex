defmodule Rabbits.PlanResolver do
  use Rabbits.Constants
  use Simulator.PlanResolver

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn is_update_valid?(action, object) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) -> Nx.tensor(1)
      both_equal(action, @add_rabbit, object, @empty) -> Nx.tensor(1)
      both_equal(action, @add_rabbit, object, @lettuce) -> Nx.tensor(1)
      both_equal(action, @keep_rabbit, object, @rabbit) -> Nx.tensor(1)
      both_equal(action, @remove_rabbit, object, @rabbit) -> Nx.tensor(1)
      true -> Nx.tensor(0)
    end
  end

  @impl true
  defn apply_action(object, plan, old_state) do
    {new_object, new_state} =
      cond do
        plans_objects_match(plan, @lettuce_grow, object, @empty) ->
          {@lettuce, old_state}

        plans_objects_match(plan, @rabbit_move, object, @empty) ->
          {@rabbit, old_state - 1}

        plans_objects_match(plan, @rabbit_move, object, @lettuce) ->
          {@rabbit, old_state + 1}

        plans_objects_match(plan, @rabbit_rest, object, @rabbit) ->
          {@rabbit, old_state - 1}

        plans_objects_match(plan, @rabbit_procreate, object, @empty) ->
          {@rabbit, @rabbit_start_energy}

        plans_objects_match(plan, @rabbit_procreate, object, @lettuce) ->
          {@rabbit, old_state}

        plans_objects_match(plan, @rabbit_die, object, @rabbit) ->
          {@empty, 0}

        true ->
          {object, old_state}
      end

    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  @impl true
  defn apply_consequence(object, plan, old_state) do
    {new_object, new_state} =
      cond do
        plans_objects_match(plan, @rabbit_procreate, object, @rabbit) ->
          # TODO procreation waste as a constant
          {@rabbit, old_state}

        plans_objects_match(plan, @rabbit_move, object, @rabbit) ->
          {@empty, old_state}

        :otherwise ->
          {object, old_state}
      end

    {new_object, Nx.broadcast(new_state, {1, 1})}
  end
end
