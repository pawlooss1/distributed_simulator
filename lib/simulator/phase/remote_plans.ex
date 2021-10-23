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
  @spec process_plans(Nx.t(), Nx.t(), Nx.t(), fun(), fun()) :: Nx.t()
  def process_plans(grid, plans, object_data, is_update_valid?, apply_update) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    order =
      0..(x_size * y_size - 1)
      |> Enum.shuffle()
      |> Nx.tensor()

    process_plans_in_order(
      grid,
      plans,
      object_data,
      order,
      is_update_valid?,
      apply_update
    )
  end

  defnp process_plans_in_order(
          grid,
          plans,
          object_data,
          order,
          is_update_valid?,
          apply_update
        ) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    {order_len} = Nx.shape(order)

    {_i, _order, _plans, _old_states, grid, object_data, _y_size, accepted_plans} =
      while {i = 0, order, plans, old_states = object_data, grid, object_data, y_size,
             accepted_plans = Nx.broadcast(@rejected, {x_size, y_size})},
            Nx.less(i, order_len) do
        ordinal = order[i]
        {x, y} = {Nx.quotient(ordinal, x_size), Nx.remainder(ordinal, y_size)}

        {grid, accepted_plans, object_data} =
          process_plan(
            x,
            y,
            plans,
            old_states,
            grid,
            accepted_plans,
            object_data,
            is_update_valid?,
            apply_update
          )

        {i + 1, order, plans, old_states, grid, object_data, y_size, accepted_plans}
      end

    {grid, accepted_plans, object_data}
  end

  defnp process_plan(
          x,
          y,
          plans,
          old_states,
          grid,
          accepted_plans,
          object_data,
          is_update_valid?,
          apply_update
        ) do
    {x_target, y_target} = shift({x, y}, plans[x][y][0])

    action = plans[x][y][1]
    object = grid[x_target][y_target][0]

    # TODO state plans must have first 2 dim as grid - mention in documentation - or delete this part and pass whole old_states?
    old_state = old_states[x][y]

    if is_update_valid?.(action, object) do
      {grid, object_data} =
        apply_update.(grid, object_data, x_target, y_target, action, object, old_state)

      accepted_plans = Nx.put_slice(accepted_plans, [x, y], Nx.broadcast(@accepted, {1, 1}))

      {grid, accepted_plans, object_data}
    else
      {grid, accepted_plans, object_data}
    end
  end
end
