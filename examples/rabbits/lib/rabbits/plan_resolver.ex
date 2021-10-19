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
      # both_equal(action, @add_person, object, @exit) -> Nx.tensor(1)
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
    {do_apply_update(grid, x, y, action, object),  object_data}
  end

  defnp do_apply_update(grid, x, y, action, object) do
    cond do
      both_equal(action, @add_lettuce, object, @empty) -> put_object(grid, x, y, @lettuce)
      # both_equal(action, @add_person, object, @exit) -> put_object(grid, x, y, @exit)
      # both_equal(action, @add_person, object, @fire) -> put_object(grid, x, y, @fire)

      # both_equal(action, @remove_person, object, @person) -> put_object(grid, x, y, @empty)

      # both_equal(action, @create_fire, object, @empty) -> put_object(grid, x, y, @fire)
      # both_equal(action, @create_fire, object, @person) -> put_object(grid, x, y, @fire)
      # both_equal(action, @create_fire, object, @exit) -> put_object(grid, x, y, @fire)

      true -> grid
    end
  end
end
