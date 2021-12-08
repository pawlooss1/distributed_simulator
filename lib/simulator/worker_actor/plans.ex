defmodule Simulator.WorkerActor.Plans do
  @moduledoc """
  Module contataining Worker's functions responsible for the plans.

  Each plan is a tensor: [direction, action, consequence].

  `direction` - a plan contains an action towards a specific
    neighboring cell. `Direction` indicates it.

  `action` - what should be the state of the target cell (pointed by
    `direction`).

  `consequence` - what should be in the current cell if the plan will
    be executed.

  Example: a person wants to move up: [@dir_up, @person, @empty].
  """

  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  alias Simulator.Types

  @doc """
  Creates plans for every cell in the grid.
  """
  @spec create_plans(Types.index(), Nx.t(), Nx.t(), fun()) :: Nx.t()
  defn create_plans(iteration, grid, objects_state, create_plan) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    # create plans only for inner grid
    {_i, plans, _grid, _objects_state, _iteration} =
      while {i = 1, plans = initial_plans(x_size, y_size), grid, objects_state, iteration},
            Nx.less(i, x_size - 1) do
        {_i, _j, plans, _grid, _objects_state, _iteration} =
          while {i, j = 1, plans, grid, objects_state, iteration},
                Nx.less(j, y_size - 1) do
            plan_as_tuple = create_plan.(i, j, plans, grid, objects_state, iteration)
            plans = add_plan(plans, i, j, plan_to_tensor(plan_as_tuple))
            {i, j + 1, plans, grid, objects_state, iteration}
          end

        {i + 1, plans, grid, objects_state, iteration}
      end

    plans
  end

  @doc """
  The function decides which plans are accepted and update the grid
  by putting `action` in the proper cells. `Consequences` will be
  applied in the `:remote_consequences` phase.
  """
  @spec process_plans(Nx.t(), Nx.t(), Nx.t(), fun(), fun()) :: {Nx.t(), Nx.t(), Nx.t()}
  @defn_compiler {EXLA, client: :default}
  defn process_plans(grid, plans, objects_state, is_update_valid?, apply_action) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    order_length = x_size * y_size

    order =
      {order_length}
      |> Nx.iota()
      |> Nx.shuffle()

    {_i, _order, _plans, _old_states, grid, objects_state, _y_size, accepted_plans} =
      while {i = 0, order, plans, old_states = objects_state, grid, objects_state, y_size,
             accepted_plans = Nx.broadcast(@rejected, {x_size, y_size})},
            Nx.less(i, order_length) do
        ordinal = order[i]
        {x, y} = {Nx.quotient(ordinal, y_size), Nx.remainder(ordinal, y_size)}

        {grid, accepted_plans, objects_state} =
          process_plan(
            x,
            y,
            plans,
            old_states,
            grid,
            accepted_plans,
            objects_state,
            is_update_valid?,
            apply_action
          )

        {i + 1, order, plans, old_states, grid, objects_state, y_size, accepted_plans}
      end

    {grid, accepted_plans, objects_state}
  end

  defnp process_plan(
          x,
          y,
          plans,
          old_states,
          grid,
          accepted_plans,
          objects_state,
          is_update_valid?,
          apply_action
        ) do
    {x_target, y_target} = shift({x, y}, plans[x][y][0])

    # don't accept plans when target localization is on the edge - it belongs to other actor
    if on_the_edge(grid, {x_target, y_target}) do
      {grid, accepted_plans, objects_state}
    else
      action = plans[x][y][1]
      object = grid[x_target][y_target][0]

      if is_update_valid?.(action, object) do
        # accept plan
        # TODO state plans must have the first 2 dim same as grid - mention in documentation
        old_state = old_states[x][y]
        plan = plans[x][y][1..2]

        {new_object, new_state} = apply_action.(object, plan, old_state)
        grid = put_object(grid, x_target, y_target, new_object)
        objects_state = Nx.put_slice(objects_state, [x_target, y_target], new_state)

        accepted_plans = Nx.put_slice(accepted_plans, [x, y], Nx.broadcast(@accepted, {1, 1}))

        {grid, accepted_plans, objects_state}
      else
        {grid, accepted_plans, objects_state}
      end
    end
  end

  defnp initial_plans(x_size, y_size) do
    Nx.broadcast(Nx.tensor([@dir_stay, @keep, @keep]), {x_size, y_size, 3})
  end

  defnp plan_to_tensor({direction, plan}) do
    direction = Nx.reshape(direction, {1})
    Nx.concatenate([direction, plan])
  end

  defnp add_plan(plans, i, j, plan) do
    Nx.put_slice(plans, [i, j, 0], Nx.broadcast(plan, {1, 1, 3}))
  end

  defnp on_the_edge(grid, {x, y}) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    Nx.less_equal(x, 0) or Nx.less_equal(y, 0) or
      Nx.greater_equal(x, x_size - 1) or Nx.greater_equal(y, y_size - 1)
  end
end
