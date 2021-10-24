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
    # TODO create function in framework object_at(grid, loc)
    {new_object, new_state} =
    cond do
      both_equal(plan, @lettuce_grow, object, @empty) ->
        {@lettuce, old_state}

      both_equal(plan, @rabbit_move, object, @empty) ->
        {@rabbit, old_state - 1}

      both_equal(plan, @rabbit_move, object, @lettuce) ->
        {@rabbit, old_state + 1}

      both_equal(plan, @rabbit_rest, object, @rabbit) ->
        {@rabbit, old_state - 1}

      both_equal(plan, @rabbit_procreate, object, @empty) ->
        # /2?
        {@rabbit, @rabbit_start_energy}

      both_equal(plan, @rabbit_procreate, object, @lettuce) ->
        {@rabbit, old_state}

      both_equal(plan, @rabbit_die, object, @rabbit) ->
        {@empty, 0}

      true ->
        {object, old_state}
    end
    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  @impl true
  defn apply_update(grid, object_data, x, y, action, object, old_state) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) ->
        do_update(grid, object_data, [x, y], @lettuce, old_state)

      both_equal(action, @add_rabbit, object, @empty) ->
        do_update(grid, object_data, [x, y], @rabbit, old_state - 1)

      both_equal(action, @add_rabbit, object, @lettuce) ->
        do_update(grid, object_data, [x, y], @rabbit, old_state + 1)

      both_equal(action, @remove_rabbit, object, @rabbit) ->
        do_update(grid, object_data, [x, y], @empty, object_data[x][y])

      true ->
        {grid, object_data}
    end
  end

  # TODO put_object loc instead x, y?
  defnp do_update(grid, object_data, loc, new_object, new_state) do
    [x,y] = loc
    {put_object(grid, x, y, new_object), put_state(object_data, loc, new_state)}
  end

  defnp put_state(object_data, loc, state) do
    Nx.put_slice(object_data, loc, Nx.broadcast(state, {1, 1}))
  end
end
