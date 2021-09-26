defmodule Simulator.Nx.WorkerActor do
  @moduledoc false

  import Nx.Defn
  import Simulator.Nx.Cell
  import Simulator.Nx.Printer

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
  @mock 1

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example).
  Currently there is also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def listen(grid) do
    receive do
      {:start_iteration, iteration} when iteration > @max_iterations ->
        :ok

      {:start_iteration, iteration} ->
        plans = create_plans(grid)
        #        IO.inspect(grid)
        distribute_plans(iteration, plans)
        listen(grid)

      {:remote_plans, iteration, plans} ->
        {updated_grid, accepted_plans} = process_plans(grid, plans)

        # todo - now action+cons applied at once
        # todo could apply alternatives as well if those existed, without changing input :D
        #
        distribute_consequences(iteration, plans, accepted_plans)
        listen(updated_grid)

      {:remote_consequences, iteration, plans, accepted_plans} ->
        updated_grid = apply_consequences(grid, plans, accepted_plans)
        signal_update = calculate_signal_updates(updated_grid)

        distribute_signal(iteration, signal_update)
        listen(updated_grid)

      {:remote_signal, iteration, signal_update} ->
        updated_grid = apply_signal_update(grid, signal_update)

        write_to_file(updated_grid, "grid_#{iteration}")

        send(self(), {:start_iteration, iteration + 1})
        listen(updated_grid)
    end
  end

  @doc """
  Each plan is a tensor: [direction, action, consequence]
  action: what should be the state of target cell (pointed by direction)
  consequence: what should be in current cell (applied only if plan executed)
  e.x.: mock wants to move up: [@dir_up, @mock, @empty]
  """
  defnp create_plans(grid) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, plans, _grid} =
      while {i = 0, plans = Nx.broadcast(Nx.tensor(0), {x_size, y_size, 3}), grid},
            Nx.less(i, x_size) do
        {_i, _j, plans, _grid} =
          while {i, j = 0, plans, grid}, Nx.less(j, y_size) do
            if Nx.equal(grid[i][j][0], @mock) do
              plan = create_plan_mock(i, j, grid)
              plans = Nx.put_slice(plans, Nx.broadcast(plan, {1, 1, 3}), [i, j, 0])
              {i, j + 1, plans, grid}
            else
              {i, j + 1, plans, grid}
            end
          end

        {i + 1, plans, grid}
      end

    plans
  end

  #  defnp create_plan_mock(i, j, grid) do
  #    direction = Nx.argmax(grid[i][j][1..8]) + 1 |> Nx.reshape({1})
  #    action_consequence = Nx.tensor([@mock, @empty])
  #
  #    Nx.concatenate([direction, action_consequence])
  #  end
  defnp create_plan_mock(i, j, grid) do
    {_i, _j, _direction, availability, availability_size, _grid} =
      while {i, j, direction = 1, availability = Nx.broadcast(Nx.tensor(0), {8}), curr = 0, grid},
            Nx.less(direction, 9) do
        {x, y} = shift({i, j}, direction)

        if can_move({x, y}, grid) do
          availability = Nx.put_slice(availability, Nx.broadcast(direction, {1}), [curr])
          {i, j, direction + 1, availability, curr + 1, grid}
        else
          {i, j, direction + 1, availability, curr, grid}
        end
      end

    index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 8})

    # todo to_scalar doesn't work in defn, and tensor([scalar-tensor, scalar, scalar]) doesnt work,
    # so to create [dir, mock, empty] we convert dir (scalar tensor)
    # to tensor of shape [1]
    direction =
      availability[index]
      |> Nx.reshape({1})

    action_consequence = Nx.tensor([@mock, @empty])

    Nx.concatenate([direction, action_consequence])
  end

  #  # todo cleaner architecture proposition, if nx implements new functions
  #  def create_plans2(grid) do
  #    {x_size, y_size, _z_size} = Nx.shape(grid)
  #
  #    plans =
  #      Nx.map(Nx.iota({x_size, y_size}), fn ordinal ->
  #        create_plan(grid[Nx.quotient(ordinal, y_size)][Nx.remainder(ordinal, y_size)])
  #      end)
  #  end
  #
  #  defn create_plan(values) do
  #    values[0]
  #  end

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

  defnp shift({x, y}, direction) do
    cond do
      Nx.equal(direction, @dir_stay) -> {x, y}
      Nx.equal(direction, @dir_top) -> {x - 1, y}
      Nx.equal(direction, @dir_top_right) -> {x - 1, y + 1}
      Nx.equal(direction, @dir_right) -> {x, y + 1}
      Nx.equal(direction, @dir_bottom_right) -> {x + 1, y + 1}
      Nx.equal(direction, @dir_bottom) -> {x + 1, y}
      Nx.equal(direction, @dir_bottom_left) -> {x + 1, y - 1}
      Nx.equal(direction, @dir_left) -> {x, y - 1}
      Nx.equal(direction, @dir_top_left) -> {x - 1, y - 1}
      # todo why? shouldn't throw? // I think we cannot throw from defn. Any suggestions what to do with that?
      true -> {0, 0}
    end
  end

  @doc """
  Checks if plan can be executed (here: if target field is empty).
  """
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

  defnp calculate_signal_updates(grid) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, grid, update_grid} =
      while {i = 0, grid, update_grid = Nx.broadcast(0, Nx.shape(grid))}, Nx.less(i, x_size) do
        {_i, _j, grid, update_grid} =
          while {i, j = 0, grid, update_grid}, Nx.less(j, y_size) do
            update_grid = signal_update_for_cell(i, j, grid, update_grid)

            {i, j + 1, grid, update_grid}
          end

        {i + 1, grid, update_grid}
      end

    update_grid
  end

  @doc """
  Standard signal update for given cell.
  """
  defnp signal_update_for_cell(x, y, grid, update_grid) do
    {_x, _y, _dir, _grid, update_grid} =
      while {x, y, dir = 1, grid, update_grid}, Nx.less(dir, 9) do
        # coords of a cell that we consider signal from
        {x2, y2} = shift({x, y}, dir)

        if is_valid({x2, y2}, grid) do
          update_value = signal_update_from_direction(x2, y2, grid, dir)

          update_grid =
            Nx.put_slice(update_grid, Nx.broadcast(update_value, {1, 1, 1}), [x, y, dir])

          {x, y, dir + 1, grid, update_grid}
        else
          {x, y, dir + 1, grid, update_grid}
        end
      end

    update_grid
  end

  @doc """
  Calculate generated + propagated signal.

  It is coming from given cell - {x_from, y_from}, from direction dir.
  Coordinates of a calling cell don't matter (but can be reconstructed moving 1 step in opposite direction).
  """
  defnp signal_update_from_direction(x_from, y_from, grid, dir) do
    is_cardinal =
      Nx.remainder(dir, 2)
      |> Nx.equal(1)

    generated_signal = generate_signal(grid[x_from][y_from][0])

    propagated_signal =
      if is_cardinal do
        grid[x_from][y_from][adj_left(dir)] + grid[x_from][y_from][dir] +
          grid[x_from][y_from][adj_right(dir)]
      else
        grid[x_from][y_from][dir]
      end

    generated_signal + propagated_signal
  end

  @doc """
  Get next direction, counterclockwise ( @top -> @top_left, @right -> @bottom_right)
  """
  defnp adj_left(dir) do
    Nx.remainder(8 + dir - 2, 8) + 1
  end

  @doc """
  Get next direction, clockwise (@top -> @top_right, @top_left -> @top)
  """
  defnp adj_right(dir) do
    Nx.remainder(dir, 8) + 1
  end

  # todo; currently it truncates signal values if they are not integers. We can consider rounding them instead
  @doc """
  Applies signal update.

  Cuts out only signal (without object) from `grid` and `signal_update`, performs applying update and puts result back
  to the `grid`.

  Applying update is making such operation on every signal value {i, j, dir}:
  s[i][j][dir] = (s[i][j][dir] + S * u[i][j][dir]) * A * f(g[i][j][0])
  where
  - s - a signal grid (3D tensor cut out from `grid`)
  - u - passed `signal update` (3D tensor)
  - g - passed `grid`
  - S - `@signal_suppression_factor`
  - A - `@signal_attenuation_factor`
  - f - `signal_factor` function - returned value depends on the contents of the cell
  """
  defnp apply_signal_update(grid, signal_update) do
    signal_factors = map_signal_factor(grid)

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

  @doc """
  Returns 3D tensor with shape {x, y, 1}, where {x, y, _z} is a shape of the passed `grid`. Tensor gives a factor for
  every cell to multiply it by signal in that cell. Value depends on the contents of the cell - obstacles block signal.
  """
  defnp map_signal_factor(grid) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, signal_factors} =
      while {i = 0, grid, signal_factors = Nx.broadcast(0, {x_size, y_size, 1})},
            Nx.less(i, x_size) do
        {_i, _j, grid, signal_factors} =
          while {i, j = 0, grid, signal_factors}, Nx.less(j, y_size) do
            cell_signal_factor = Nx.broadcast(signal_factor(grid[i][j][0]), {1, 1, 1})
            signal_factors = Nx.put_slice(signal_factors, cell_signal_factor, [i, j, 0])

            {i, j + 1, grid, signal_factors}
          end

        {i + 1, grid, signal_factors}
      end

    signal_factors
  end

  @doc """
  Checks whether the mock can move to position {x, y}.
  """
  defnp can_move({x, y}, grid) do
    [is_valid({x, y}, grid), Nx.equal(grid[x][y][0], 0)]
    |> Nx.stack()
    |> Nx.all?()
  end

  @doc """
  Checks if position {x, y} is inside the grid.
  """
  defnp is_valid({x, y}, grid) do
    {x_size, y_size, _} = Nx.shape(grid)

    [
      Nx.greater_equal(x, 0),
      Nx.less(x, x_size),
      Nx.greater_equal(y, 0),
      Nx.less(y, y_size)
    ]
    |> Nx.stack()
    |> Nx.all?()
  end

  @doc """
  Send each plan to worker managing cells affected by this plan.
  """
  defp distribute_plans(iteration, plans) do
    send(self(), {:remote_plans, iteration, plans})
  end

  @doc """
  Send each consequence to worker managing cells affected by this plan consequence.
  """
  defp distribute_consequences(iteration, plans, accepted_plans) do
    send(self(), {:remote_consequences, iteration, plans, accepted_plans})
  end

  @doc """
  Send each signal to worker managing cells affected by this signal.
  """
  defp distribute_signal(iteration, signal_update) do
    send(self(), {:remote_signal, iteration, signal_update})
  end
end
