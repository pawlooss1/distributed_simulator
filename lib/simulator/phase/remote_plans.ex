defmodule Simulator.Phase.RemotePlans do
  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  # todo; make our own shuffle to use it in defn
  @spec process_plans(Nx.t(), Nx.t()) :: Nx.t()
  def process_plans(grid, plans) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    order =
      0..(x_size * y_size - 1)
      |> Enum.shuffle()
      |> Nx.tensor()

    process_plans_in_order(grid, plans, order)
  end

  defnp process_plans_in_order(grid, plans, order) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    {order_len} = Nx.shape(order)

    {_i, _order, _plans, grid, _y_size, accepted_plans} =
      while {i = 0, order, plans, grid, y_size,
             accepted_plans = Nx.broadcast(0, {x_size, y_size})},
            Nx.less(i, order_len) do
        ordinal = order[i]
        {x, y} = {Nx.quotient(ordinal, y_size), Nx.remainder(ordinal, y_size)}
        {grid, accepted_plans} = process_plan(x, y, plans, grid, accepted_plans)

        {i + 1, order, plans, grid, y_size, accepted_plans}
      end

    {grid, accepted_plans}
  end

  defnp process_plan(x, y, plans, grid, accepted_plans) do
    object = grid[x][y][0]

    if Nx.equal(object, @empty) do
      {grid, accepted_plans}
    else
      {x_target, y_target} = shift({x, y}, plans[x][y][0])

      if validate_plan(grid, plans, x, y) do
        action = plans[x][y][1]

        grid = Nx.put_slice(grid, Nx.broadcast(action, {1, 1, 1}), [x_target, y_target, 0])
        accepted_plans = Nx.put_slice(accepted_plans, Nx.broadcast(1, {1, 1}), [x, y])

        {grid, accepted_plans}
      else
        {grid, accepted_plans}
      end
    end
  end

  # Checks if plan can be executed (here: if target field is empty).
  defnp validate_plan(grid, plans, x, y) do
    direction = plans[x][y][0]

    if Nx.equal(direction, @dir_stay) do
      Nx.tensor(1)
    else
      {x2, y2} = shift({x, y}, direction)
      Nx.equal(grid[x2][y2][0], @empty)
    end
  end
end
