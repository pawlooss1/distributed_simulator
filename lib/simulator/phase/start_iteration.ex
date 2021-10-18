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
  defn create_plans(iteration, grid, object_data, create_plan) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, plans, _grid, _iteration} =
      while {i = 0, plans = initial_plans(x_size, y_size), grid, iteration},
            Nx.less(i, x_size) do
        {_i, _j, plans, _grid, _iteration} =
          while {i, j = 0, plans, grid, iteration}, Nx.less(j, y_size) do
            # TODO object_data not needed in loops?
            create_plan.(i, j, plans, grid, object_data, iteration)
          end

        {i + 1, plans, grid, iteration}
      end

    plans
  end

  defnp initial_plans(x_size, y_size) do
    Nx.broadcast(Nx.tensor([@dir_stay, @empty, @empty]), {x_size, y_size, 3})
  end
end
