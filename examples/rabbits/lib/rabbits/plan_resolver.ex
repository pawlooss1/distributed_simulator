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
      both_equal(action, @remove_rabbit, object, @rabbit) -> Nx.tensor(1)
      true -> Nx.tensor(0)
    end
  end

  @impl true
  defn apply_action(grid, object_data, x, y, plan, old_state) do
    {x_target, y_target} = shift({x, y}, plan[0])

    action = plan[1]
    object = grid[x_target][y_target][0]
    cond do
      both_equal(action, @add_lettuce, object, @empty) ->
        do_update(grid, object_data, x, y, @lettuce, old_state)

      both_equal(action, @add_rabbit, object, @empty) ->
        do_update(grid, object_data, x, y, @rabbit, old_state - 1)

      both_equal(action, @add_rabbit, object, @lettuce) ->
        do_update(grid, object_data, x, y, @rabbit, old_state + 1)

      both_equal(action, @remove_rabbit, object, @rabbit) ->
        do_update(grid, object_data, x, y, @empty, object_data[x][y])

      true ->
        {grid, object_data}
    end
  end

  @impl true
  defn apply_update(grid, object_data, x, y, action, object, old_state) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) ->
        do_update(grid, object_data, x, y, @lettuce, old_state)

      both_equal(action, @add_rabbit, object, @empty) ->
        do_update(grid, object_data, x, y, @rabbit, old_state - 1)

      both_equal(action, @add_rabbit, object, @lettuce) ->
        do_update(grid, object_data, x, y, @rabbit, old_state + 1)

      both_equal(action, @remove_rabbit, object, @rabbit) ->
        do_update(grid, object_data, x, y, @empty, object_data[x][y])

      true ->
        {grid, object_data}
    end
  end

  defnp do_update(grid, object_data, x, y, new_object, new_state) do
    {put_object(grid, x, y, new_object), put_state(object_data, x, y, new_state)}
  end

  defnp put_state(object_data, i, j, state) do
    Nx.put_slice(object_data, [i, j], Nx.broadcast(state, {1, 1}))
  end
end
