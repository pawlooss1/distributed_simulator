defmodule Evacuation.PlanCreator do
  use Evacuation.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(i, j, plans, grid, iteration) do
    cond do
      Nx.equal(grid[i][j][0], @person) ->
        plan = create_plan_person(i, j, grid)
        plans = Nx.put_slice(plans, [i, j, 0], Nx.broadcast(plan, {1, 1, 3}))
        {i, j + 1, plans, grid, iteration}

      Nx.equal(grid[i][j][0], @fire) ->
        plan = create_plan_fire(i, j, grid, iteration)
        plans = Nx.put_slice(plans, [i, j, 0], Nx.broadcast(plan, {1, 1, 3}))
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
            Nx.put_slice(signals, [direction - 1], Nx.broadcast(grid[i][j][direction], {1}))

          {i, j, direction + 1, signals, grid}
        else
          signals = Nx.put_slice(signals, [direction - 1], Nx.broadcast(-@infinity, {1}))
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
            availability = Nx.put_slice(availability, [curr], Nx.broadcast(direction, {1}))
            {i, j, direction + 1, availability, curr + 1, grid}
          else
            {i, j, direction + 1, availability, curr, grid}
          end
        end

      index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 8})

      # todo to_scalar doesn't work in defn, and tensor([scalar-tensor, scalar, scalar]) doesnt work,
      # so to create [dir, mock, empty] we convert dir (scalar tensor)
      # to tensor of shape [1]
      direction = Nx.reshape(availability[index], {1})
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
