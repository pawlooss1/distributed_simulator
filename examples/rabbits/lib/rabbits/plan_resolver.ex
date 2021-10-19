defmodule Rabbits.PlanResolver do
  use Rabbits.Constants
  use Simulator.PlanResolver

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  # TODO why?
  defn is_update_valid?(action, object) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) -> Nx.tensor(1)
      both_equal(action, @add_rabbit, object, @empty) -> Nx.tensor(1)
      both_equal(action, @add_rabbit, object, @lettuce) -> Nx.tensor(1)
      both_equal(action, @remove_rabbit, object, @rabbit) -> Nx.tensor(1)
      # both_equal(action, @add_person, object, @fire) -> Nx.tensor(1)

      # both_equal(action, @remove_person, object, @person) -> Nx.tensor(1)

      # both_equal(action, @create_fire, object, @empty) -> Nx.tensor(1)
      # both_equal(action, @create_fire, object, @person) -> Nx.tensor(1)
      # both_equal(action, @create_fire, object, @exit) -> Nx.tensor(1)

      true -> Nx.tensor(0)
    end
  end

  @impl true
  defn apply_update(grid, object_data, x, y, action, object) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) -> {put_object(grid, x, y, @lettuce), object_data}
      both_equal(action, @add_rabbit, object, @empty) ->
        {put_object(grid, x, y, @rabbit), Nx.put_slice(object_data, [x, y], Nx.broadcast(object_data[x][y]-1, {1, 1})) }
      both_equal(action, @add_rabbit, object, @lettuce) ->
        {put_object(grid, x, y, @rabbit), Nx.put_slice(object_data, [x, y], Nx.broadcast(object_data[x][y]+1, {1, 1})) }
      both_equal(action, @remove_rabbit, object, @rabbit) -> {put_object(grid, x, y, @empty), object_data}

      true -> {grid, object_data}
    end
  end

end
