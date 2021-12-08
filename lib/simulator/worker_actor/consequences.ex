defmodule Simulator.WorkerActor.Consequences do
  @moduledoc """
  Module contataining a Worker's function responsible for the 
  consequences.
  """

  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  @doc """
  Applies all consequences from the accepted plans.
  # TODO maybe should receive old objects_state as well?
  """
  @spec apply_consequences(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun()) :: Nx.t()
  defn apply_consequences(grid, objects_state, plans, accepted_plans, apply_consequence) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, grid, objects_state, _plans, _accepted_plans} =
      while {i = 0, grid, objects_state, plans, accepted_plans}, Nx.less(i, x_size) do
        {_i, _j, grid, objects_state, plans, accepted_plans} =
          while {i, j = 0, grid, objects_state, plans, accepted_plans}, Nx.less(j, y_size) do
            if Nx.equal(accepted_plans[i][j], @accepted) do
              object = grid[i][j][0]

              {new_object, new_state} =
                apply_consequence.(object, plans[i][j][1..2], objects_state[i][j])

              grid = put_object(grid, i, j, new_object)
              objects_state = Nx.put_slice(objects_state, [i, j], new_state)

              {i, j + 1, grid, objects_state, plans, accepted_plans}
            else
              {i, j + 1, grid, objects_state, plans, accepted_plans}
            end
          end

        {i + 1, grid, objects_state, plans, accepted_plans}
      end

    {grid, objects_state}
  end
end
