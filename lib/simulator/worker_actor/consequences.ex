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
  """
  @spec apply_consequences(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun()) :: {Nx.t(), Nx.t()}
  defn apply_consequences(grid, objects_state, plans, accepted_plans, apply_consequence) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    # flatten "directions" dimension
    plans = Nx.reduce_max(plans, axes: [0])

    {_i, grid, objects_state, _plans, _accepted_plans} =
      while {i = 0, grid, objects_state, plans, accepted_plans}, Nx.less(i, x_size) do
        {_i, _j, grid, objects_state, plans, accepted_plans} =
          while {i, j = 0, grid, objects_state, plans, accepted_plans}, Nx.less(j, y_size) do
            if Nx.equal(accepted_plans[i][j], @accepted) do
              object = grid[i][j][0]

              {new_object, new_state} =
                apply_consequence.(object, plans[i][j], objects_state[i][j])

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

  @doc """
  Applies all consequences from the accepted plans.
  """
  @spec apply_consequences(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun()) :: {Nx.t(), Nx.t()}
  defn apply_consequences_2(grid, objects_state, plans, accepted_plans, _apply_consequence) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    # flatten "directions" dimension
    plans = Nx.reduce_max(plans, axes: [0])

    {_i, grid, objects_state, _plans, _accepted_plans} =
      while {i = 0, grid, objects_state, plans, accepted_plans}, Nx.less(i, x_size) do
        {_i, _j, grid, objects_state, plans, accepted_plans} =
          while {i, j = 0, grid, objects_state, plans, accepted_plans}, Nx.less(j, y_size) do
            plan_with_object = grid[i][j][0]
            consequence = plan_with_object &&& @leave_consequence_filter

            grid =
              if Nx.not_equal(consequence, @keep) do
                direction = (plan_with_object &&& @leave_direction_filter) >>> @direction_position
                {x_target, y_target} = shift({i, j}, opposite(direction))
                target_object = grid[x_target][y_target][0]

                new_object = apply_consequence(target_object, consequence)
                put_object(grid, x_target, y_target, new_object)
              else
                grid
              end

            grid = put_object(grid, i, j, plan_with_object &&& @leave_object_filter)
            {i, j + 1, grid, objects_state, plans, accepted_plans}
          end

        {i + 1, grid, objects_state, plans, accepted_plans}
      end

    {grid, objects_state}
  end

  defn apply_consequence(object, consequence) do
    # TODO przeniesc do ewakuacji i zrobic callback (jak calosc bedzie dzialac)
    # TODO uwzglednic objects_state
    cond do
      # remove person
      consequence == 0b0010_0000 -> @empty
      # shouldn't happen, in evacuation removing is the only non-zero consequence
      true -> object
    end
  end
end
