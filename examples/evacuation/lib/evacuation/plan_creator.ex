defmodule Evacuation.PlanCreator do
  import Nx.Defn
  import Simulator.Helpers

  @behaviour Simulator.PlanCreator

  @infinity 1_000_000_000

  @fire_spreading_frequency 5

  @empty 0
  @person 1
  @obstacle 2
  @exit 3
  @fire 4

  @impl true
  defn create_plan(i, j, plans, grid, iteration) do
    cond do
      Nx.equal(grid[i][j][0], @person) ->
        plan = create_plan_person(i, j, grid)
        plans = Nx.put_slice(plans, Nx.broadcast(plan, {1, 1, 3}), [i, j, 0])
        {i, j + 1, plans, grid, iteration}

      Nx.equal(grid[i][j][0], @fire) ->
        plan = create_plan_fire(i, j, grid, iteration)
        plans = Nx.put_slice(plans, Nx.broadcast(plan, {1, 1, 3}), [i, j, 0])
        {i, j + 1, plans, grid, iteration}

      :otherwise ->
        {i, j + 1, plans, grid, iteration}
    end
  end

  defnp create_plan_person(i, j, grid) do
    {_i, _j, _direction, signals, _grid} =
      while {i, j, direction = 1, signals = Nx.broadcast(Nx.tensor(0), {8}), grid},
            Nx.less(direction, 9) do
        {x, y} = shift({i, j}, direction)

        if can_move({x, y}, grid) do
          signals =
            Nx.put_slice(signals, Nx.broadcast(grid[i][j][direction], {1}), [direction - 1])

          {i, j, direction + 1, signals, grid}
        else
          signals = Nx.put_slice(signals, Nx.broadcast(-@infinity, {1}), [direction - 1])
          {i, j, direction + 1, signals, grid}
        end
      end

    if signals |> Nx.reduce_max() |> Nx.greater(-@infinity) do
      direction = Nx.argmax(signals) |> Nx.reshape({1})
      action_consequence = Nx.tensor([@person, @empty])

      Nx.concatenate([direction, action_consequence])
    else
      Nx.tensor([0, 0, 0])
    end
  end

  defnp create_plan_fire(i, j, grid, iteration) do
    if Nx.remainder(iteration, @fire_spreading_frequency) |> Nx.equal(Nx.tensor(0)) do
      {_i, _j, _direction, availability, availability_size, _grid} =
        while {i, j, direction = 1, availability = Nx.broadcast(Nx.tensor(0), {8}), curr = 0,
               grid},
              Nx.less(direction, 9) do
          {x, y} = shift({i, j}, direction)

          if can_burn({x, y}, grid) do
            availability = Nx.put_slice(availability, Nx.broadcast(direction, {1}), [curr])
            {i, j, direction + 1, availability, curr + 1, grid}
          else
            {i, j, direction + 1, availability, curr, grid}
          end
        end

      index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 8})

      # todo to_scalar doesn't work in defn, and tensor([scalar-tensor, scalar, scalar]) doesnt work,
      # so to create [dir, mock, empty] we convert dir (scalar tensor)
      # to tensor of shape [1]
      direction =
        availability[index]
        |> Nx.reshape({1})

      action_consequence = Nx.tensor([@fire, @fire])

      Nx.concatenate([direction, action_consequence])
    else
      Nx.tensor([0, 0, 0])
    end
  end

  defnp can_burn({x, y}, grid) do
    [is_valid({x, y}, grid), Nx.not_equal(grid[x][y][0], @obstacle)]
    |> Nx.stack()
    |> Nx.all?()
  end
end
