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
    {x_size, y_size, _z_size} = Nx.shape(grid)

    # create plans only for inner grid
    {_i, plans, _grid, _objects_state, _iteration, _rng} =
      while {i = 0, plans = initial_plans(x_size, y_size), grid, objects_state, iteration, rng},
            Nx.less(i, x_size) do
        {_i, _j, plans, _grid, _objects_state, _iteration, _rng} =
          while {i, j = 0, plans, grid, objects_state, iteration, rng},
                Nx.less(j, y_size) do
            {direction, plan} = create_plan.(i, j, grid, objects_state, iteration, rng)
            plans = add_plan(plans, direction, i, j, plan)
            {i, j + 1, plans, grid, objects_state, iteration, rng}
          end

        {i + 1, plans, grid, objects_state, iteration, rng}
      end

    plans
  end

  @doc """
  Creates plans for every cell in the grid.
  """
  @spec create_plans_2(Types.index(), Nx.t(), Nx.t(), Nx.t(), fun()) :: Nx.t()
  defn create_plans_2(iteration, grid, objects_state, rng, create_plan) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    # create plans only for inner grid
    {_i, plans, _grid, _objects_state, _iteration, _rng} =
      while {i = 0, plans = initial_plans_2(grid), grid, objects_state, iteration, rng},
            Nx.less(i, x_size) do
        {_i, _j, plans, _grid, _objects_state, _iteration, _rng} =
          while {i, j = 0, plans, grid, objects_state, iteration, rng},
                Nx.less(j, y_size) do
            plan = create_plan.(i, j, grid, objects_state, iteration, rng)
            # plans = Nx.put_slice(plans, [i, j], Nx.broadcast(plan |> Nx.as_type({:s, 32}), {1, 1}))
            plans = Nx.put_slice(plans, [i, j], Nx.broadcast(plan, {1, 1}))
            {i, j + 1, plans, grid, objects_state, iteration, rng}
          end

        {i + 1, plans, grid, objects_state, iteration, rng}
      end

    plans
  end

    @doc """
  The function decides which plans are accepted and update the grid
  by putting `action` in the proper cells. `Consequences` will be
  applied in the `:remote_consequences` phase.
  """
  @spec process_plans(Nx.t(), Nx.t(), Nx.t(), Nx.t(), fun(), fun()) :: {Nx.t(), Nx.t(), Nx.t()}
  defn process_plans_2(grid, plans, objects_state, order, _is_update_valid?, _apply_action) do
    # todo podawac apply_action
    processed_grid = new_process_plans(plans, order)
    grid = Nx.put_slice(grid, [0, 0, 0], Nx.new_axis(processed_grid, -1))
    # todo accepted_plans do wywalki
    accepted_plans = plans
    # todo objects_state: wyciagnac z processed_grid albo na stale zespolic z grid
    {grid, accepted_plans, objects_state}
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

  defnp initial_plans_2(grid) do
    grid[[.., .., 0]]
  end

  defnp add_plan(plans, direction, i, j, plan) do
    Nx.put_slice(plans, [direction, i, j, 0], Nx.broadcast(plan, {1, 1, 1, 2}))
  end

  # TODO spiąć z całością
  defn new_process_plans(plans, order) do
    {col_plans, shape} = grid_to_col(plans)
    col_plans = apply_plan_filter(col_plans, order)
    col_to_grid(col_plans, shape)
  end

  defn apply_plan_filter(col_grid, order) do
    filtered_by_direction = filter_right_directions(col_grid)
    accepted_plans = choose_accepted_plans(filtered_by_direction, order)
    accepted_plans_to_result(accepted_plans)
  end

  defn choose_accepted_plans(col_plans, order) do
    {n_rows, _} = Nx.shape(col_plans)

    {_, col_plans, _} =
      while {row = 0, col_plans, order}, Nx.less(row, n_rows) do
        new_value = choose_plan_from_row(col_plans[row], order)
        col_plans = Nx.put_slice(col_plans, [row, 4], Nx.reshape(new_value, {1, 1}))
        # TODO przetestowac czy losowanie dla kazdego wiersza zmienia wydajnosc
        {row + 1, col_plans, order}
      end

    col_plans[[.., 4]]
  end

  defn accepted_plans_to_result(plans) do
    {size} = Nx.shape(plans)

    {_, plans} =
      while {i = 0, plans}, Nx.less(i, size) do
        # todo: przeniesc wyciaganie obiektow filtrami, apply_action ma miec trzy argumenty
        plans = Nx.put_slice(plans, [i], Nx.reshape(apply_action(plans[i]), {1}))
        {i + 1, plans}
      end

    plans
  end

  defn apply_action(plan_with_object) do
    # TODO przeniesc do ewakuacji i zrobic callback (jak calosc bedzie dzialac)
    # TODO uwzglednic objects_state
    object = Nx.bitwise_and(plan_with_object, @leave_object_filter)
    direction_plan = Nx.bitwise_and(plan_with_object, @leave_plan_filter)
    plan = Nx.bitwise_and(plan_with_object, @leave_undirected_plan_filter)

    cond do
      # person_move
      Nx.equal(plan, 0b0001_0010_0000) ->
        cond do
          # osoba wchodzi na pole
          Nx.equal(object, 0b0000) -> direction_plan + 0b0001
          # osoba wchodzi do wyjscia
          Nx.equal(object, 0b0011) -> direction_plan + 0b0011
          # osoba wchodzi w ogien
          Nx.equal(object, 0b0100) -> direction_plan + 0b0100
          # osoba nie moze wejsc na inna osobe ani na przeszkode
          true -> object
        end

      # fire_spread
      Nx.equal(plan, 0b0011_0000_0000) ->
        cond do
          # ogien nie zajmuje przeszkod
          Nx.equal(object, 0b0010) -> 0b0010
          # ogien sie rozprzestrzenia
          true -> direction_plan + 0b0100
        end

      # brak planu
      true ->
        object
    end
  end

  defn choose_plan_from_row(row, order) do
    # object <=> row[4]
    # result = Nx.tensor(0, type: {:s, 32})
    result = 0
    {_, _, _, result} =
      while {i = 0, row, order, result}, Nx.less(i, 8) and Nx.equal(result, 0) do
        plan = row[order[i]]

        result =
          if not Nx.equal(plan, 0) do
            plan + row[4]
          else
            0
          end

        {i + 1, row, order, result}
      end

    if Nx.equal(result, 0) do
      row[4]
    else
      result
    end
  end

  defn filter_right_directions(col_grid) do
    only_directions = Nx.bitwise_and(col_grid, @leave_direction_filter)
    col_grid * Nx.equal(only_directions, get_filter_proper_directions())
  end

  # wymyslic nazwe
  defn grid_to_col(grid) do
    {x, y} = shape = Nx.shape(grid)
    # result = Nx.broadcast(Nx.tensor(0, type: {:s, 32}), {x * y, 9})
    result = Nx.broadcast(Nx.tensor(0), {x * y, 9})
    grid = Nx.pad(grid, 0, [{1, 1, 0}, {1, 1, 0}])

    {_i, result, _grid} =
      while {i = 0, result, grid}, Nx.less(i, x) do
        {_i, _j, result, _grid} =
          while {i, j = 0, result, grid}, Nx.less(j, y) do
            slice = Nx.slice(grid, [i, j], [3, 3])

            row = Nx.bitwise_and(Nx.reshape(slice, {1, 9}), @neigh_to_row_filter)

            result = Nx.put_slice(result, [i * x + j, 0], row)
            {i, j + 1, result, grid}
          end

        {i + 1, result, grid}
      end

    {result, shape}
  end

  defn col_to_grid(result, shape) do
    Nx.reshape(result, shape)
  end

  defn get_filter_proper_directions() do
    # 4, 5, 6, 3, 0, 7, 2, 1, 8
    Nx.tensor([16384, 20480, 24576, 12288, 0, 28672, 8192, 4096, 32768])
  end
end
