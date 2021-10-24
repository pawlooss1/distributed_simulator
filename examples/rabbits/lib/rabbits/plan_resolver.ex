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
      plans_equal(plan, @lettuce_grow, object, @empty) ->
        {@lettuce, old_state}

      plans_equal(plan, @rabbit_move, object, @empty) ->
        {@rabbit, old_state - 1}

      plans_equal(plan, @rabbit_move, object, @lettuce) ->
        {@rabbit, old_state + 1}

      plans_equal(plan, @rabbit_rest, object, @rabbit) ->
        {@rabbit, old_state - 1}

      plans_equal(plan, @rabbit_procreate, object, @empty) ->
        {@rabbit, @rabbit_start_energy}

      plans_equal(plan, @rabbit_procreate, object, @lettuce) ->
        {@rabbit, old_state}

      plans_equal(plan, @rabbit_die, object, @rabbit) ->
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
      plans_equal(plan, @rabbit_procreate, object, @rabbit) ->
        {@rabbit, old_state} # TODO procreation waste as a constant
      plans_equal(plan, @rabbit_move, object, @rabbit) ->
        {@empty, old_state}
      :otherwise ->
        {object, old_state}
    end
    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  defnp put_state(object_data, loc, state) do
    Nx.put_slice(object_data, loc, Nx.broadcast(state, {1, 1}))
  end

  defnp plans_equal(plan_a, plan_b, object_a, object_b) do
    Nx.all?(Nx.equal(plan_a, plan_b)) and Nx.equal(object_a, object_b)
  end
end
