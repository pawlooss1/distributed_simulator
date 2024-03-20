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
  @spec create_plans(Types.index(), Nx.t(), Nx.t(), Nx.t(), fun()) :: Nx.t()
  defn create_plans(iteration, grid, objects_state, rng, create_plan) do
    create_plan.(grid, objects_state, iteration, rng)
  end

  defn process_plans(grid, objects_state, rng, action_mappings, map_state) do
    grid_without_signals = grid[[.., .., 0]]
    accepted_plans = choose_plans(grid_without_signals, rng)
    plans_with_objects = combine_plans_with_objects(grid_without_signals, accepted_plans)
    apply_actions(plans_with_objects, objects_state, action_mappings, map_state)
  end

  defn apply_actions(grid, objects_state, action_mappings, map_state) do
    filters = action_mappings.()
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

  defn choose_plans(grid, rng) do
    grid
    |> attach_neighbourhood_to_new_dim()
    |> filter_right_directions()
    |> resolve_conflicts(rng)
  end

  defn combine_plans_with_objects(grid, plans) do
    (grid &&& @object_filter) + (plans &&& @plan_filter)
  end

  defn filter_right_directions(grid) do
    neigh = grid[[.., .., 1..-1//1]]
    directions = neigh &&& @direction_filter
    filter = (directions == @reverse_directions)
    neigh * filter
  end

  defn resolve_conflicts(plans, rng) do
    {r, _} = Nx.Random.uniform(rng, shape: {1, 8})
    plan_flags = (plans != 0)
    probabilities = plan_flags * r
    filter = find_max_filter(probabilities)
    Nx.sum(plans * filter, axes: [2])
  end

  defn find_max_filter(probabilities) do
    probabilities_t = Nx.transpose(probabilities, axes: [2, 0, 1])
    filter_t = (probabilities_t >= Nx.reduce_max(probabilities, axes: [2]))
    Nx.transpose(filter_t, axes: [1, 2, 0])
  end

  @doc """
  The function decides which plans are accepted and update the grid
  by putting `action` in the proper cells. `Consequences` will be
  applied in the `:remote_consequences` phase.
  """
  @spec process_plans(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun(), fun()) :: {Nx.t(), Nx.t(), Nx.t()}
  defn process_plans(grid, plans, objects_state, order, is_update_valid?, apply_action) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_k, _order, _plans, _old_states, grid, objects_state, accepted_plans} =
      while {k = 0, order, plans, old_states = objects_state, grid, objects_state,
             accepted_plans = Nx.broadcast(@rejected, {x_size, y_size})},
            # 8 directions
            Nx.less(k, 8) do
        {_k, _x, _order, _plans, _old_states, grid, objects_state, accepted_plans} =
          while {k, x = 0, order, plans, old_states, grid, objects_state, accepted_plans},
                Nx.less(x, x_size) do
            {_k, _x, _y, _order, _plans, _old_states, grid, objects_state, accepted_plans} =
              while {k, x, y = 0, order, plans, old_states, grid, objects_state, accepted_plans},
                    Nx.less(y, y_size) do
                # directions are starting from 1
                direction = order[k] - 1

                {grid, accepted_plans, objects_state} =
                  process_plan(
                    direction,
                    x,
                    y,
                    plans[direction][x][y],
                    old_states,
                    grid,
                    accepted_plans,
                    objects_state,
                    is_update_valid?,
                    apply_action
                  )

                {k, x, y + 1, order, plans, old_states, grid, objects_state, accepted_plans}
              end

            {k, x + 1, order, plans, old_states, grid, objects_state, accepted_plans}
          end

        {k + 1, order, plans, old_states, grid, objects_state, accepted_plans}
      end

    {grid, accepted_plans, objects_state}
  end

  defnp process_plan(
          direction,
          x,
          y,
          plan,
          old_states,
          grid,
          accepted_plans,
          objects_state,
          is_update_valid?,
          apply_action
        ) do
    {x_target, y_target} = shift({x, y}, direction)

    action = plan[0]
    object = grid[x_target][y_target][0]

    if is_update_valid?.(action, object) do
      # accept plan
      old_state = old_states[x][y]

      {new_object, new_state} = apply_action.(object, plan, old_state)
      grid = put_object(grid, x_target, y_target, new_object)
      objects_state = Nx.put_slice(objects_state, [x_target, y_target], new_state)

      accepted_plans = Nx.put_slice(accepted_plans, [x, y], Nx.broadcast(@accepted, {1, 1}))

      {grid, accepted_plans, objects_state}
    else
      {grid, accepted_plans, objects_state}
    end

    # end
  end

  defnp initial_plans(x_size, y_size) do
    Nx.broadcast(Nx.tensor([@keep, @keep]), {8, x_size, y_size, 2})
  end

  defnp add_plan(plans, direction, i, j, plan) do
    Nx.put_slice(plans, [direction, i, j, 0], Nx.broadcast(plan, {1, 1, 1, 2}))
  end
end
