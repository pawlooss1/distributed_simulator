defmodule Evacuation.PlanCreator do
  use Evacuation.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(grid, _objects_state, iteration, rng) do
    grid_without_signals = grid[[.., .., 0]]
    plan_directions = calc_plan_directions(grid)
    person_plans = create_plan_person(grid_without_signals, plan_directions)
    {fire_plans, rng} = create_plan_fire(grid_without_signals, iteration, rng)
    plans = grid[[.., .., 0]] + person_plans + fire_plans
    {plans, rng}
  end

  defn create_plan_person(grid, directions) do
    create_plans_for_object_type(grid, directions, @person, @person_move)
  end

  defn create_plan_fire(grid, iteration, rng) do
    if Nx.remainder(iteration, @fire_spreading_frequency) |> Nx.equal(Nx.tensor(0)) do
      {directions, rng} = choose_available_directions_randomly(grid, rng, fn g -> g != @obstacle end)
      {create_plans_for_object_type(grid, directions, @fire, @fire_spread), rng}
    else
      {Nx.broadcast(0, Nx.shape(grid)), rng}
    end
  end
end
