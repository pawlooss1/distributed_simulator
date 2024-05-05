defmodule Rabbits.PlanCreator do
  use Rabbits.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(grid, objects_state, iteration, rng) do
    grid_without_signals = grid[[.., .., 0]]
    plan_directions = calc_plan_directions(grid)
    {rabbit_plans, rng} = create_plan_rabbit(grid_without_signals, objects_state, plan_directions, rng)
    {lettuce_plans, rng} = create_plan_lettuce(grid_without_signals, objects_state, iteration, rng)
    plans = grid_without_signals + rabbit_plans + lettuce_plans
    {plans, rng}
  end

  defn create_plan_rabbit(grid, objects_state, directions, rng) do
    dead_rabbit_filter = fn g, os -> g == @rabbit and os < 1 end

    die_plans =
      create_plans_without_dir_for_object_type(
        grid,
        objects_state,
        @rabbit_die,
        dead_rabbit_filter
      )

      availability_filter = fn g -> g == @empty or g == @lettuce end
    {procreate_directions, rng} = choose_available_directions_randomly(grid, rng, availability_filter)
    procreative_rabbit_filter = fn g, os -> g == @rabbit and os > @rabbit_reproduction_energy end

    procreate_plans =
      create_plans_for_object_type(
        grid,
        objects_state,
        procreate_directions,
        @rabbit_procreate,
        procreative_rabbit_filter
      )

      moving_rabbit_filter = fn g, os -> g == @rabbit and os >= 1 and os <= @rabbit_reproduction_energy end

      move_plans =
        create_plans_for_object_type(
          grid,
          objects_state,
          directions,
          @rabbit_move,
          moving_rabbit_filter
        )
        {die_plans + procreate_plans + move_plans, rng}
  end

  defn create_plan_lettuce(grid, objects_state, iteration, rng) do
    if Nx.remainder(iteration, @lettuce_growth_factor) |> Nx.equal(Nx.tensor(0)) do
      {directions, rng} = choose_available_directions_randomly(grid, rng, &Nx.equal(&1, @empty))
      plans = create_plans_for_object_type(
        grid,
        objects_state,
        directions,
        @lettuce_grow,
        fn g, _ -> g == @lettuce end
      )
      {plans, rng}
    else
      {Nx.broadcast(@keep, Nx.shape(grid)), rng}
    end
  end
end
