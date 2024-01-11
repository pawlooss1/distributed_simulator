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

  # WIP, na razie nie "usuwa" planu z komórki początkowej
  defn process_plans_2(plans, order) do
    {col_plans, shape} = grid_to_col(plans)
    col_plans = apply_plan_filter(col_plans, order[0])
    col_plans = apply_plan_filter(col_plans, order[1])
    col_plans = apply_plan_filter(col_plans, order[2])
    col_plans = apply_plan_filter(col_plans, order[3])
    col_plans = apply_plan_filter(col_plans, order[4])
    col_plans = apply_plan_filter(col_plans, order[5])
    col_plans = apply_plan_filter(col_plans, order[6])
    col_plans = apply_plan_filter(col_plans, order[7])
    col_to_grid(col_plans, shape)
  end

  # wymyslic nazwe
  defn grid_to_col(grid) do
    {x, y} = shape = Nx.shape(grid)
    result = Nx.broadcast(Nx.tensor(0), {x * y, 9})
    grid = Nx.pad(grid, 0, [{1, 1, 0}, {1, 1, 0}])

    {_i, result, _grid} =
      while {i = 0, result, grid}, Nx.less(i, x) do
        {_i, _j, result, _grid} =
          while {i, j = 0, result, grid}, Nx.less(j, y) do
            slice = Nx.slice(grid, [i, j], [3, 3])
            row = if Nx.equal(slice[1][1], 0) do
              # this cell is free, we should look at the plans
              Nx.reshape(slice, {1, 9})
            else
              # this cell is occupied, we should discard plans next to it
              leave_only_center(Nx.reshape(slice, {1, 9}))
            end
            result = Nx.put_slice(result, [i * x + j, 0], row)
            {i, j + 1, result, grid}
          end

        {i + 1, result, grid}
      end
    {result, shape}
  end

  defn col_to_grid(col_grid, shape) do
    Nx.reshape(col_grid[[.., 4]], shape)
  end

  defn apply_plan_filter(col_grid, filter_direction) do
    filter = get_filter(filter_direction)
    # przesuń wszystkie plany
    accepted_plans = Nx.dot(col_grid, filter)
    # zostaw tylko plany o właściwym kierunku
    accepted_plans =  Nx.multiply(accepted_plans, Nx.equal(filter_direction, Nx.abs(accepted_plans)))
    update = Nx.broadcast(Nx.tensor(0), Nx.shape(col_grid))
    # zgodne plany przechodzą do środkowej kolumny - z niej odtwarzamy siatkę
    update = Nx.put_slice(update, [0, 4], Nx.reshape(accepted_plans, {9, 1}))
    # TODO: odejmujemy plany które zostały przeniesione
    # korekta w kolumnie, a nie wierszu
    # możliwe, że nie -> zamiast tego struktura accepted_plans
    # Update: korekta trudna do realizacji, prawnopodobnie accepted_plans,
    # ale jeszcze muszę przemyśleć jak rozwiązać apply_action
    # w kontekście objects_state
    # pierwszy pomysł - lookup table zamiast tych case'ów
    # poza tym trzeba pomyśleć o is_update_valid? - w królikach agent
    # może wejść (a nawet będzie miał w planie) na pole z sałatą
    discard_surrounding_plans(col_grid + update)
  end

  defn discard_surrounding_plans(col_grid) do
    # zostawiamy "uzupełnienia"
    complements = Nx.multiply(col_grid, Nx.less(col_grid, 0))
    # jak środek równy 0, to otoczenie (plany) zostaje
    filter_out = Nx.equal(0, col_grid[[.., 4..4]])
    # w.p.p. usuwamy plany
    filter_in = 1 - filter_out
    filter = Nx.concatenate([
      filter_out,
      filter_out,
      filter_out,
      filter_out,
      filter_in,
      filter_out,
      filter_out,
      filter_out,
      filter_out,
    ], axis: 1)
    col_grid * filter + complements
  end

  defn get_filter(dir) do
    filters = Nx.tensor([
      [0, 0, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 1, 0, 0],
      [0, 0, 0, 1, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 1],
    ])
    filters[dir]
  end

  defn get_update_column_index(dir) do
    indices = Nx.tensor([4, 7, 6, 3, 0, 1, 2, 5, 8])
    indices[dir]
  end

  defn leave_only_center(row) do
    Nx.multiply(row, Nx.tensor([0, 0, 0, 0, 1, 0, 0, 0, 0]))
    # choose_row_with_complement(row[[0, 4]]) - raczej do wywalki
  end

  defn choose_row_with_complement(dir) do
    rows = Nx.tensor([
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 1, 0, 0,-1, 0],
      [0, 0, 0, 0, 2, 0,-2, 0, 0],
      [0, 0, 0,-3, 3, 0, 0, 0, 0],
      [-4,0, 0, 0, 4, 0, 0, 0, 0],
      [0,-5, 0, 0, 5, 0, 0, 0, 0],
      [0, 0,-6, 0, 6, 0, 0, 0, 0],
      [0, 0, 0, 0, 7,-7, 0, 0, 0],
      [0, 0, 0, 0, 8, 0, 0, 0,-8]
    ])
    rows[dir]
  end
end
