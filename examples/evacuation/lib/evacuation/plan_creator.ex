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
    fire_plans = create_plan_fire(grid_without_signals, iteration, rng)
    plans = grid[[.., .., 0]] + person_plans + fire_plans
    plans
  end

  defn create_plan_person(grid, directions) do
    create_plans_for_object_type(grid, directions, @person, @person_move)
  end

  defn create_plan_fire(grid, iteration, rng) do
    if Nx.remainder(iteration, @fire_spreading_frequency) |> Nx.equal(Nx.tensor(0)) do
      {r, _} = Nx.Random.uniform(rng, shape: {1, 8})
      available_fields = grid != @obstacle
      available_neighbourhood = attach_neighbourhood_to_new_dim(available_fields)
      directions = Nx.argmax(available_neighbourhood[[.., .., 1..-1//1]] * r, axis: 2) + 1

      create_plans_for_object_type(grid, directions, @fire, @fire_spread)
    else
      Nx.broadcast(0, Nx.shape(grid))
    end
  end

  defn create_plans_for_object_type(grid, directions, object, plan) do
    directions = (grid == object) * directions
    filter = directions != 0
    plans = filter * plan
    plans + (directions <<< @direction_position)
  end

  # TODO probalby move to the framework
  defn calc_plan_directions(grid) do
    # TODO move to a const
    filter =
      Nx.complex(
        Nx.tensor([1, 0.7071067690849304, 0, -0.7071067690849304, -1, -0.7071067690849304, 0, 0.7071067690849304]),
        Nx.tensor([0, 0.7071067690849304, 1, 0.7071067690849304, 0, -0.7071067690849304, -1, -0.7071067690849304])
      )

    resultants = Nx.dot(grid[[.., .., 1..8]], filter)

    resultants
    |> Nx.phase()
    |> radian_to_direction()
    # 0 + i0 has angle = 0 too hence the correction
    |> Nx.multiply(resultants != Nx.complex(0, 0))
    |> Nx.as_type(Nx.type(grid))
  end

  defn radian_to_direction(angles) do
    Nx.round(angles * 4 / Nx.Constants.pi())
    # correction because Nx.phase results are from (-pi, pi]
    |> Nx.add(8)
    |> Nx.remainder(8)
    # angle = 0 -> dir = 1, etc.
    |> Nx.add(1)
  end
end
