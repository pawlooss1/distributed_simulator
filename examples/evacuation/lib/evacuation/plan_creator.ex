defmodule Evacuation.PlanCreator do
  use Evacuation.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(grid, objects_state, iteration, rng) do
    grid_without_signals = grid[[.., .., 0]]
    plan_directions = calc_plan_directions(grid)
    person_plans = create_plan_person(grid_without_signals, objects_state, plan_directions)
    {fire_plans, rng} = create_plan_fire(grid_without_signals, objects_state, iteration, rng)
    plans = grid_without_signals + person_plans + fire_plans
    {plans, rng}
  end

  defn create_plan_person(grid, objects_state, directions) do
    create_plans_for_object_type(grid, objects_state, directions, @person_move, fn g, _ ->
      g == @person
    end)
  end

  defn create_plan_fire(grid, objects_state, iteration, rng) do
    if Nx.remainder(iteration, @fire_spreading_frequency) |> Nx.equal(Nx.tensor(0)) do
      {directions, rng} =
        choose_available_directions_randomly(grid, rng, &Nx.not_equal(&1, @obstacle))

      plans =
        create_plans_for_object_type(
          grid,
          objects_state,
          directions,
          @fire_spread,
          fn g, _ -> g == @fire end
        )

      {plans, rng}
    else
      {Nx.broadcast(@keep, Nx.shape(grid)), rng}
    end
  end
end
