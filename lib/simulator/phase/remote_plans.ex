defmodule Simulator.Phase.RemotePlans do
  @moduledoc """
  Module contataining the function called during the
  `:remote_plans` phase.
  """

  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  @doc """
  The function decides which plans are accepted and update the grid
  by putting `action` in the proper cells. `Consequences` will be
  applied in the `:remote_consequences` phase.

  TODO make our own shuffle to use it in defn.
  """
  @spec process_plans(Nx.t(), Nx.t(), fun(), fun()) :: Nx.t()
  def process_plans(grid, plans, is_update_valid?, apply_update) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    order =
      0..(x_size * y_size - 1)
      |> Enum.shuffle()
      |> Nx.tensor()

    process_plans_in_order(grid, plans, order, is_update_valid?, apply_update)
  end

  defnp process_plans_in_order(grid, plans, order, is_update_valid?, apply_update) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    {order_len} = Nx.shape(order)

    {_i, _order, _plans, grid, _y_size, accepted_plans} =
      while {i = 0, order, plans, grid, y_size,
             accepted_plans = Nx.broadcast(@rejected, {x_size, y_size})},
            Nx.less(i, order_len) do
        ordinal = order[i]
        {x, y} = {Nx.quotient(ordinal, x_size), Nx.remainder(ordinal, y_size)}

        {grid, accepted_plans} =
          process_plan(x, y, plans, grid, accepted_plans, is_update_valid?, apply_update)

        {i + 1, order, plans, grid, y_size, accepted_plans}
      end

    {grid, accepted_plans}
  end

  defnp process_plan(x, y, plans, grid, accepted_plans, is_update_valid?, apply_update) do
    {x_target, y_target} = shift({x, y}, plans[x][y][0])

    action = plans[x][y][1]
    object = grid[x_target][y_target][0]

    if is_update_valid?.(action, object) do
      grid = apply_update.(grid, x_target, y_target, action, object)
      accepted_plans = Nx.put_slice(accepted_plans, [x, y], Nx.broadcast(@accepted, {1, 1}))

      {grid, accepted_plans}
    else
      {grid, accepted_plans}
    end
  end
end
