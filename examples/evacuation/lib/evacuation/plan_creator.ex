defmodule Evacuation.PlanCreator do
  use Evacuation.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(i, j, grid, _objects_state, iteration, rng) do
    cond do
      Nx.equal(grid[i][j][0], @person) ->
        create_plan_person(i, j, grid)

      Nx.equal(grid[i][j][0], @fire) ->
        create_plan_fire(i, j, grid, iteration, rng)

      true ->
        create_plan_other(i, j, grid)
    end
  end

  defn create_plan(grid, objects_state, iteration, rng) do
    plan_directions = calc_plan_directions(grid)
    # TODO finish plans for people and fire
  end

  defn create_plan_person(grid, directions) do
    directions = (grid == 1) * directions

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
    |> Nx.multiply(resultants != Nx.complex(0, 0)) # 0 + i0 has angle = 0 too hence the correction
    |> Nx.as_type(Nx.type(grid))
  end

  defn radian_to_direction(angles) do
    Nx.round(angles * 4 / Nx.Constants.pi)
    |> Nx.add(8) # correction because Nx.phase results are from (-pi, pi]
    |> Nx.remainder(8)
    |> Nx.add(1) # angle = 0 -> dir = 1, etc.
  end

  defnp create_plan_person(i, j, grid) do
    {_i, _j, _direction, signals, _grid} =
      while {i, j, direction = @dir_top, signals = Nx.broadcast(Nx.tensor(@dir_stay), {9}),
             grid},
            Nx.less_equal(direction, @dir_top_left) do
        {x, y} = shift({i, j}, direction)

        signals =
          if Nx.equal(grid[x][y][0], @empty) or Nx.equal(grid[x][y][0], @exit) do
            Nx.put_slice(signals, [direction], Nx.broadcast(grid[i][j][direction], {1}))
          else
            Nx.put_slice(signals, [direction], Nx.broadcast(@dir_stay, {1}))
          end

        {i, j, direction + 1, signals, grid}
      end

    max = Nx.reduce_max(signals)
    min = Nx.reduce_min(signals)
    diff = Nx.add(max, min)

    cond do
      diff |> Nx.greater(0) ->
        # positive signal is stronger
        {Nx.argmax(signals), @person_move}
      diff |> Nx.less(0) ->
        # negative signal is stronger
        {opposite(Nx.argmin(signals)), @person_move}
      max |> Nx.greater(0) ->
        # pos and ned signals are non-zero but same strength
        # we choose positive
        {Nx.argmax(signals), @person_move}
      true ->
        # no non-neutral signal
        {@dir_stay, @plan_keep}
    end
  end

  defnp create_plan_fire(i, j, grid, iteration, rng) do
    if Nx.remainder(iteration, @fire_spreading_frequency) |> Nx.equal(Nx.tensor(0)) do
      {_i, _j, _direction, availability, availability_size, _grid} =
        while {i, j, direction = 1, availability = Nx.broadcast(Nx.tensor(0), {8}), curr = 0,
               grid},
              Nx.less(direction, 9) do
          {x, y} = shift({i, j}, direction)

          if can_burn({x, y}, grid) do
            availability = Nx.put_slice(availability, [curr], Nx.broadcast(direction, {1}))
            {i, j, direction + 1, availability, curr + 1, grid}
          else
            {i, j, direction + 1, availability, curr, grid}
          end
        end

      if availability_size > 0 do
        rng = Nx.Random.fold_in(rng, i * 7 + j * 5)
        {index, _new_rng} = Nx.Random.randint(rng, 0, availability_size)
        {availability[index], @fire_spread}
      else
        {@dir_stay, @plan_keep}
      end
    else
      {@dir_stay, @plan_keep}
    end
  end

  defnp can_burn({x, y}, grid) do
    [is_valid({x, y}, grid), Nx.not_equal(grid[x][y][0], @obstacle)]
    |> Nx.stack()
    |> Nx.all()
  end

  defnp create_plan_other(_i, _j, _grid) do
    {@dir_stay, @plan_keep}
  end
end
