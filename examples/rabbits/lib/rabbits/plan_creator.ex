defmodule Rabbits.PlanCreator do
  use Rabbits.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(i, j, plans, state_plans, grid, object_data, iteration) do
    # TODO rabbits and lettuce create state_plan as well!
    plan =
      cond do
        Nx.equal(grid[i][j][0], @rabbit) ->
          create_plan_rabbit(i, j, grid, object_data)

        Nx.equal(grid[i][j][0], @lettuce) ->
          create_plan_lettuce(i, j, grid, iteration)

        :otherwise ->
          create_plan_other(i, j, grid)
      end

    plans = add_plan(plans, i, j, plan)
    {i, j + 1, plans, state_plans, grid, object_data, iteration}
  end

  defnp create_plan_rabbit(i, j, grid, object_data) do

        # TODO all rabbits go up when signal is 0
        # TODO procreate and die depending on energy
        if Nx.equal(object_data[i][j], 0) do
            Nx.tensor([@dir_stay, @remove_rabbit, @keep])
        else
    {_i, _j, _direction, signals, _grid} =
      while {i, j, direction = @dir_top, signals = Nx.broadcast(Nx.tensor(-@infinity), {9}), grid},
            Nx.less_equal(direction, @dir_top_left) do
        {x, y} = shift({i, j}, direction)

        signals =
          if Nx.equal(grid[x][y][0], @empty) or Nx.equal(grid[x][y][0], @lettuce) do
            Nx.put_slice(signals, [direction], Nx.broadcast(grid[i][j][direction], {1}))
          else
            Nx.put_slice(signals, [direction], Nx.broadcast(-@infinity, {1}))
          end

        {i, j, direction + 1, signals, grid}
      end

    if signals |> Nx.reduce_max() |> Nx.greater(-@infinity) do
      direction = Nx.argmax(signals)

      action_consequence = Nx.tensor([@add_rabbit, @remove_rabbit])

      Nx.concatenate([Nx.reshape(direction, {1}), action_consequence])
    else
      Nx.tensor([@dir_stay, @keep, @keep])
    end
  end

  end

  # TODO refer to direction as 1 or @top?
  defnp create_plan_lettuce(i, j, grid, iteration) do
    if Nx.remainder(iteration, @lettuce_growth_factor) |> Nx.equal(Nx.tensor(0)) do
      {_i, _j, _direction, availability, availability_size, _grid} =
        while {i, j, direction = 1, availability = Nx.broadcast(Nx.tensor(0), {8}), curr = 0, grid},
              Nx.less(direction, 9) do
          {x, y} = shift({i, j}, direction)

          if Nx.equal(grid[x][y][0], @empty) do
            availability = Nx.put_slice(availability, [curr], Nx.broadcast(direction, {1}))
            {i, j, direction + 1, availability, curr + 1, grid}
          else
            {i, j, direction + 1, availability, curr, grid}
          end
        end
        # TODO fire in EVACUATION will error when av size == 0
        if availability_size > 0 do
          index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 8})

          # to create [dir, mock, empty] we convert dir (scalar tensor) to tensor of shape [1]
          direction = Nx.reshape(availability[index], {1})
          action_consequence = Nx.tensor([@add_lettuce, @keep])
          Nx.concatenate([direction, action_consequence])
        else
          Nx.tensor([@dir_stay, @keep, @keep])
        end
    else
      Nx.tensor([@dir_stay, @keep, @keep])
    end
  end

  defnp create_plan_other(_i, _j, _grid) do
    Nx.tensor([@dir_stay, @keep, @keep])
  end

  defnp add_plan(plans, i, j, plan) do
    Nx.put_slice(plans, [i, j, 0], Nx.broadcast(plan, {1, 1, 3}))
  end
end
