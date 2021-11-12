defmodule Simulator.Phase.StartIteration do
  @moduledoc """
  Module contataining the function called during the
  `:start_iteration` phase.
  """

  use Simulator.BaseConstants

  import Nx.Defn

  alias Simulator.Types

  @doc """
  Each plan is a tensor: [direction, action, consequence].

  `direction` - a plan contains an action towards a specific
    neighboring cell. `Direction` indicates it.

  `action` - what should be the state of the target cell (pointed by
    `direction`).

  `consequence` - what should be in the current cell if the plan will
    be executed.

  Example: a person wants to move up: [@dir_up, @person, @empty].
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
end
