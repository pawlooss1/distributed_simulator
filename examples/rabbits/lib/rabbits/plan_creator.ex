defmodule Rabbits.PlanCreator do
  use Rabbits.Constants
  use Simulator.PlanCreator

  import Nx.Defn
  import Simulator.Helpers

  @impl true
  defn create_plan(i, j, grid, objects_state, iteration) do
    cond do
      Nx.equal(grid[i][j][0], @rabbit) ->
        create_plan_rabbit(i, j, grid, objects_state)

      Nx.equal(grid[i][j][0], @lettuce) ->
        create_plan_lettuce(i, j, grid, iteration)

      true ->
        create_plan_other(i, j, grid)
    end
  end

  defnp create_plan_rabbit(i, j, grid, objects_state) do
    cond do
      Nx.less(objects_state[i][j], 1) ->
        rabbit_die()

      Nx.greater(objects_state[i][j], @rabbit_reproduction_energy) ->
        rabbit_procreate(grid, i, j)

     true ->
        rabbit_move(grid, i, j)
    end
  end

  defnp rabbit_die() do
    {@dir_stay, @rabbit_die}
  end

  defnp rabbit_procreate(grid, i, j) do
    {_i, _j, _direction, availability, availability_size, _grid} =
      while {i, j, direction = @dir_top, availability = Nx.broadcast(Nx.tensor(0), {8}), curr = 0,
             grid},
            Nx.less_equal(direction, @dir_top_left) do
        {x, y} = shift({i, j}, direction)

        if Nx.equal(grid[x][y][0], @empty) or Nx.equal(grid[x][y][0], @lettuce) do
          availability = Nx.put_slice(availability, [curr], Nx.broadcast(direction, {1}))
          {i, j, direction + 1, availability, curr + 1, grid}
        else
          {i, j, direction + 1, availability, curr, grid}
        end
      end

    if availability_size > 0 do
      index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 32})
      {availability[index], @rabbit_procreate}
    else
      {@dir_stay, @rabbit_rest}
    end
  end

  defnp rabbit_move(grid, i, j) do
    {_i, _j, _direction, signals, _grid} =
      while {i, j, direction = @dir_top, signals = Nx.broadcast(Nx.tensor(-@infinity), {9}),
             grid},
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
      {direction, @rabbit_move}
    else
      {@dir_stay, @rabbit_rest}
    end
  end

  defnp create_plan_lettuce(i, j, grid, iteration) do
    if Nx.remainder(iteration, @lettuce_growth_factor) |> Nx.equal(Nx.tensor(0)) do
      {_i, _j, _direction, availability, availability_size, _grid} =
        while {i, j, direction = @dir_top, availability = Nx.broadcast(Nx.tensor(0), {8}),
               curr = 0, grid},
              Nx.less(direction, @dir_top_left) do
          {x, y} = shift({i, j}, direction)

          if Nx.equal(grid[x][y][0], @empty) do
            availability = Nx.put_slice(availability, [curr], Nx.broadcast(direction, {1}))
            {i, j, direction + 1, availability, curr + 1, grid}
          else
            {i, j, direction + 1, availability, curr, grid}
          end
        end

      if availability_size > 0 do
        index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 32})
        {availability[index], @lettuce_grow}
      else
        {@dir_stay, @plan_keep}
      end
    else
      {@dir_stay, @plan_keep}
    end
  end

  defnp create_plan_other(_i, _j, _grid) do
    {@dir_stay, @plan_keep}
  end
end
