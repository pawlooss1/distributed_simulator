defmodule Simulator.WorkerActor do
  @moduledoc false

  import Nx.Defn
  import Simulator.Cell
  import Simulator.Helpers
  import Simulator.Printer

  # TODO maybe we can add necessary attributes via macros? (e.g. using `use`)
  @infinity 1_000_000_000

  @dir_stay 0
  @dir_top 1
  @dir_top_right 2
  @dir_right 3
  @dir_bottom_right 4
  @dir_bottom 5
  @dir_bottom_left 6
  @dir_left 7
  @dir_top_left 8

  @max_iterations 25
  @signal_suppression_factor 0.4
  @signal_attenuation_factor 0.4

  @empty 0
  @person 1
  @obstacle 2
  @exit 3
  @fire 4

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example).
  Currently there is also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def listen(grid, functions) do
    receive do
      {:start_iteration, iteration} when iteration > @max_iterations ->
        :ok

      {:start_iteration, iteration} ->
        plans = create_plans(iteration, grid, functions[:create_plan])

        IO.inspect(plans)

        distribute_plans(iteration, plans)
        send(self(), {:start_iteration, iteration + 1})
        listen(grid, functions)

      {:remote_plans, iteration, plans} ->
        {updated_grid, accepted_plans} = process_plans(grid, plans)

        # todo - now action+cons applied at once
        # todo could apply alternatives as well if those existed, without changing input :D
        #
        distribute_consequences(iteration, plans, accepted_plans)
        listen(updated_grid, functions)

      {:remote_consequences, iteration, plans, accepted_plans} ->
        updated_grid = apply_consequences(grid, plans, accepted_plans)
        signal_update = calculate_signal_updates(updated_grid, functions[:generate_signal])

        distribute_signal(iteration, signal_update)
        listen(updated_grid, functions)

      {:remote_signal, iteration, signal_update} ->
        updated_grid = apply_signal_update(grid, signal_update, functions[:signal_factor])

        write_to_file(updated_grid, "grid_#{iteration}")

        send(self(), {:start_iteration, iteration + 1})
        listen(updated_grid, functions)
    end
  end

  # Each plan is a tensor: [direction, action, consequence]
  # action: what should be the state of target cell (pointed by direction)
  # consequence: what should be in current cell (applied only if plan executed)
  # e.g.: mock wants to move up: [@dir_up, @mock, @empty]
  defnp create_plans(iteration, grid, create_plan) do
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

  # todo; make our own shuffle to use it in defn
  defp process_plans(grid, plans) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    order =
      0..(x_size * y_size - 1)
      |> Enum.shuffle()
      |> Nx.tensor()

    process_plans_in_order(grid, plans, order)
  end

  defnp process_plans_in_order(grid, plans, order) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    {order_len} = Nx.shape(order)

    {_i, _order, _plans, grid, _y_size, accepted_plans} =
      while {i = 0, order, plans, grid, y_size,
              accepted_plans = Nx.broadcast(0, {x_size, y_size})},
            Nx.less(i, order_len) do
        ordinal = order[i]
        {x, y} = {Nx.quotient(ordinal, y_size), Nx.remainder(ordinal, y_size)}
        {grid, accepted_plans} = process_plan(x, y, plans, grid, accepted_plans)

        {i + 1, order, plans, grid, y_size, accepted_plans}
      end

    {grid, accepted_plans}
  end

  defnp process_plan(x, y, plans, grid, accepted_plans) do
    object = grid[x][y][0]

    if Nx.equal(object, @empty) do
      {grid, accepted_plans}
    else
      {x_target, y_target} = shift({x, y}, plans[x][y][0])

      if Nx.equal(grid[x_target][y_target][0], @empty) do
        action = plans[x][y][1]

        grid = Nx.put_slice(grid, Nx.broadcast(action, {1, 1, 1}), [x_target, y_target, 0])
        accepted_plans = Nx.put_slice(accepted_plans, Nx.broadcast(1, {1, 1}), [x, y])

        {grid, accepted_plans}
      else
        {grid, accepted_plans}
      end
    end
  end

  # Checks if plan can be executed (here: if target field is empty).
  defnp validate_plan(grid, plans, x, y) do
    direction = plans[x][y]

    cond do
      Nx.equal(direction, @dir_stay) ->
        true

      :otherwise ->
        {x2, y2} = shift({x, y}, direction)
        Nx.equal(grid[x2][y2][0], @empty)
    end
  end

  defnp apply_consequences(grid, plans, accepted_plans) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, grid, _plans, _accepted_plans} =
      while {i = 0, grid, plans, accepted_plans}, Nx.less(i, x_size) do
        {_i, _j, grid, plans, accepted_plans} =
          while {i, j = 0, grid, plans, accepted_plans}, Nx.less(j, y_size) do
            # todo could apply alternative here
            if Nx.equal(accepted_plans[i][j], 1) do
              consequence = plans[i][j][2]
              grid = Nx.put_slice(grid, Nx.broadcast(consequence, {1, 1, 1}), [i, j, 0])
              {i, j + 1, grid, plans, accepted_plans}
            else
              {i, j + 1, grid, plans, accepted_plans}
            end
          end

        {i + 1, grid, plans, accepted_plans}
      end

    grid
  end

  defnp calculate_signal_updates(grid, generate_signal) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, update_grid} =
      while {i = 0, grid, update_grid = Nx.broadcast(0, Nx.shape(grid))}, Nx.less(i, x_size) do
        {_i, _j, grid, update_grid} =
          while {i, j = 0, grid, update_grid}, Nx.less(j, y_size) do
            update_grid = signal_update_for_cell(i, j, grid, update_grid, generate_signal)

            {i, j + 1, grid, update_grid}
          end

        {i + 1, grid, update_grid}
      end

    update_grid
  end

  # Standard signal update for given cell.
  defnp signal_update_for_cell(x, y, grid, update_grid, generate_signal) do
    {_x, _y, _dir, _grid, update_grid} =
      while {x, y, dir = 1, grid, update_grid}, Nx.less(dir, 9) do
        # coords of a cell that we consider signal from
        {x2, y2} = shift({x, y}, dir)

        if is_valid({x2, y2}, grid) do
          update_value = signal_update_from_direction(x2, y2, grid, dir, generate_signal)

          update_grid =
            Nx.put_slice(update_grid, Nx.broadcast(update_value, {1, 1, 1}), [x, y, dir])

          {x, y, dir + 1, grid, update_grid}
        else
          {x, y, dir + 1, grid, update_grid}
        end
      end

    update_grid
  end

  # Calculate generated + propagated signal.
  #
  # It is coming from given cell - {x_from, y_from}, from direction dir.
  # Coordinates of a calling cell don't matter (but can be reconstructed moving 1 step in opposite direction).
  defnp signal_update_from_direction(x_from, y_from, grid, dir, generate_signal) do
    is_cardinal =
      Nx.remainder(dir, 2)
      |> Nx.equal(1)

    generated_signal = generate_signal.(grid[x_from][y_from][0])

    propagated_signal =
      if is_cardinal do
        grid[x_from][y_from][adj_left(dir)] + grid[x_from][y_from][dir] +
          grid[x_from][y_from][adj_right(dir)]
      else
        grid[x_from][y_from][dir]
      end

    generated_signal + propagated_signal
  end

  # Gets next direction, counterclockwise ( @top -> @top_left, @right -> @bottom_right)
  defnp adj_left(dir) do
    Nx.remainder(8 + dir - 2, 8) + 1
  end

  # Gets next direction, clockwise (@top -> @top_right, @top_left -> @top)
  defnp adj_right(dir) do
    Nx.remainder(dir, 8) + 1
  end

  # todo; currently it truncates signal values if they are not integers. We can consider rounding them instead

  # Applies signal update.
  #
  # Cuts out only signal (without object) from `grid` and `signal_update`, performs applying update and puts result back
  # to the `grid`.
  #
  # Applying update is making such an operation on every signal value {i, j, dir}:
  # s[i][j][dir] = (s[i][j][dir] + S * u[i][j][dir]) * A * f(g[i][j][0])
  # where
  # - s - a signal grid (3D tensor cut out from `grid`)
  # - u - passed `signal update` (3D tensor)
  # - g - passed `grid`
  # - S - `@signal_suppression_factor`
  # - A - `@signal_attenuation_factor`
  # - f - `signal_factor` function - returned value depends on the contents of the cell
  defnp apply_signal_update(grid, signal_update, signal_factor) do
    signal_factors = map_signal_factor(grid, signal_factor)

    signal = Nx.slice_axis(grid, 1, 8, 2)

    updated_signal =
      signal_update
      |> Nx.slice_axis(1, 8, 2)
      |> Nx.multiply(@signal_suppression_factor)
      |> Nx.add(signal)
      |> Nx.multiply(@signal_attenuation_factor)
      |> Nx.multiply(signal_factors)
      |> Nx.as_type({:s, 64})

    Nx.put_slice(grid, updated_signal, [0, 0, 1])
  end

  # Returns 3D tensor with shape {x, y, 1}, where {x, y, _z} is a shape of the passed `grid`. Tensor gives a factor for
  # every cell to multiply it by signal in that cell. Value depends on the contents of the cell - obstacles block signal.
  defnp map_signal_factor(grid, signal_factor) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, signal_factors} =
      while {i = 0, grid, signal_factors = Nx.broadcast(0, {x_size, y_size, 1})},
            Nx.less(i, x_size) do
        {_i, _j, grid, signal_factors} =
          while {i, j = 0, grid, signal_factors}, Nx.less(j, y_size) do
            cell_signal_factor = Nx.broadcast(signal_factor.(grid[i][j][0]), {1, 1, 1})
            signal_factors = Nx.put_slice(signal_factors, cell_signal_factor, [i, j, 0])

            {i, j + 1, grid, signal_factors}
          end

        {i + 1, grid, signal_factors}
      end

    signal_factors
  end

  # Send each plan to worker managing cells affected by this plan.
  defp distribute_plans(iteration, plans) do
    send(self(), {:remote_plans, iteration, plans})
  end

  # Send each consequence to worker managing cells affected by this plan consequence.
  defp distribute_consequences(iteration, plans, accepted_plans) do
    send(self(), {:remote_consequences, iteration, plans, accepted_plans})
  end

  # Send each signal to worker managing cells affected by this signal.
  defp distribute_signal(iteration, signal_update) do
    send(self(), {:remote_signal, iteration, signal_update})
  end
end
