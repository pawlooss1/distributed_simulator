defmodule Simulator.Phase.StartIteration do
  use Simulator.BaseConstants

  import Nx.Defn

  @doc """
  Each plan is a tensor: [direction, action, consequence]
  action: what should be the state of target cell (pointed by direction)
  consequence: what should be in current cell (applied only if plan executed)
  e.g.: mock wants to move up: [@dir_up, @mock, @empty]
  """
  defn create_plans(iteration, grid, create_plan) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, plans, _grid, _iteration} =
      while {i = 0, plans = Nx.broadcast(Nx.tensor(0), {x_size, y_size, 3}), grid, iteration},
            Nx.less(i, x_size) do
        {_i, _j, plans, _grid, _iteration} =
          while {i, j = 0, plans, grid, iteration}, Nx.less(j, y_size) do
            create_plan.(i, j, plans, grid, iteration)
          end

        {i + 1, plans, grid, iteration}
      end

    plans
  end
end
