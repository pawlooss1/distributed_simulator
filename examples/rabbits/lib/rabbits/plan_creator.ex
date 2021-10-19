defmodule Rabbits.PlanCreator do
  use Rabbits.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(i, j, plans, grid, object_data, iteration) do
    plan =
      cond do
        Nx.equal(grid[i][j][0], @rabbit) ->
          create_plan_rabbit(i, j, grid)

        Nx.equal(grid[i][j][0], @lettuce) ->
          create_plan_lettuce(i, j, grid, iteration)

        :otherwise ->
          create_plan_other(i, j, grid)
      end

    plans = add_plan(plans, i, j, plan)
    {i, j + 1, plans, grid, iteration}
  end

  defnp create_plan_rabbit(i, j, grid) do
    Nx.tensor([@dir_stay, @keep, @keep])

  end

  defnp create_plan_lettuce(i, j, grid, iteration) do
    Nx.tensor([@dir_stay, @keep, @keep])
  end

  defnp create_plan_other(_i, _j, _grid) do
    Nx.tensor([@dir_stay, @keep, @keep])
  end

  defnp add_plan(plans, i, j, plan) do
    Nx.put_slice(plans, [i, j, 0], Nx.broadcast(plan, {1, 1, 3}))
  end
end
