defmodule Simulator.WorkerActor.Consequences do
  @moduledoc """
  Module contataining a Worker's function responsible for the
  consequences.
  """

  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  defn process_consequences(grid, objects_state, consequence_mappings, map_state) do
    accepted_plans = choose_plans(grid)
    plans_with_objects = combine_plans_with_objects(grid, accepted_plans)
    {updated_grid, updated_state} = apply_consequences(plans_with_objects, objects_state, consequence_mappings, map_state)
    {updated_grid &&& @object_filter, updated_state}
  end

  defn choose_plans(grid) do
    grid
    |> attach_neighbourhood_to_new_dim()
    |> filter_right_directions()
    |> Nx.sum(axes: [2])
  end

  defn combine_plans_with_objects(grid, plans) do
    (grid &&& @object_filter) + (plans &&& @plan_filter)
  end

  defn apply_consequences(grid, objects_state, consequence_mappings, map_state) do
    filters = consequence_mappings.()
    {n, _} = Nx.shape(filters)

    {_, _, _, _, _, objects_update, state_update, updated_cells} =
      while {
              i = 0,
              filters,
              objects_state,
              grid,
              g = grid &&& @action_object_filter,
              objects_update = Nx.broadcast(0, Nx.shape(grid)),
              state_update = Nx.broadcast(0, Nx.shape(objects_state)),
              updated_cells = Nx.broadcast(0, Nx.shape(grid))
            },
            i < n do
        filter = filters[i][0]
        object_update = filters[i][1]
        fun_label = filters[i][2]

        filtered_g = g == filter
        u_po = filtered_g * (object_update + (grid &&& @plan_filter))
        s_po = filtered_g * map_state.(objects_state, fun_label)

        {i + 1, filters, objects_state, grid, g, objects_update + u_po, state_update + s_po,
         updated_cells + filtered_g}
      end

    unmodified_cells = not updated_cells
    updated_grid = unmodified_cells * grid + objects_update
    updated_state = unmodified_cells * objects_state + state_update
    {updated_grid, updated_state}
  end

  defn filter_right_directions(grid) do
    neigh = grid[[.., .., 1..-1//1]]
    directions = neigh &&& @direction_filter
    filter = (directions == @directions)
    neigh * filter
  end

  @doc """
  Applies all consequences from the accepted plans.
  """
  @spec apply_consequences(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun()) :: {Nx.t(), Nx.t()}
  defn apply_consequences(grid, objects_state, plans, accepted_plans, apply_consequence) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    plans = Nx.reduce_max(plans, axes: [0]) # flatten "directions" dimension

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
end
