defmodule WorkerActor do
  @moduledoc false

  import Cell
  import Nx.Defn
#  import Position
  import Utils

  @dir_stay 0
  @dir_top 1
  @dir_top_right 2
  @dir_right 3
  @dir_bottom_right 4
  @dir_bottom 5
  @dir_bottom_left 6
  @dir_left 7
  @dir_top_left 8

  @max_iterations 5
  @signal_suppression_factor 0.4
  @signal_attenuation_factor 0.4

  @empty 0
  @mock 1

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example).
  Currently there is also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def listen grid do
    receive do
      {:start_iteration, iteration} when iteration > @max_iterations ->
        IO.puts "terminating worker"

      {:start_iteration, iteration} ->
        plans = create_plans(grid)

        distribute_plans(iteration, plans)
        listen(grid)

      {:remote_plans, iteration, plans} ->
        IO.inspect plans
        {updated_grid, accepted_plans} = process_plans(grid, plans)
        IO.inspect updated_grid
        IO.inspect accepted_plans
#        consequences = Enum.map(accepted_plans, fn {_, consequence} -> consequence end)
#
#        distribute_consequences(iteration, consequences)
#        listen(updated_grid, neighbors_by_coords, signal_by_coords)
#
#      {:remote_consequences, iteration, consequences} ->
#        updated_grid = apply_consequences(cells_by_coords, consequences)
#
#        distribute_signal(iteration, calculate_signal_updates(cells_by_coords, neighbors_by_coords, signal_by_coords))
#        listen(updated_grid, neighbors_by_coords, signal_by_coords)
#
#      {:remote_signal, iteration, signal_updates} ->
#        updated_signal = apply_signal_updates(signal_by_coords, signal_updates, cells_by_coords)
#        write_to_file(cells_by_coords, updated_signal, "grid_#{iteration}")
#
#        send(self(), {:start_iteration, iteration + 1})
#        listen(cells_by_coords, neighbors_by_coords, updated_signal)
    end
  end

    @doc """
    Each plan is a tensor: [direction, action, consequence]
    action: what should be the state of target cell (pointed by direction)
    consequence: what should be in current cell (applied only if plan executed)
    e.x.: mock wants to move up: [@dir_up, @mock, @empty]
    """
  defn create_plans(grid) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, plans, _grid} =
      while {i = 0, plans = Nx.broadcast(Nx.tensor(0), {x_size, y_size, 3}), grid}, Nx.less(i, x_size) do
        {_i, _j, plans, _grid} =
          while {i, j = 0, plans, grid}, Nx.less(j, y_size) do
            if Nx.equal(grid[i][j][0], @mock) do
              plan = create_plan_mock(i, j, grid)
              plans = Nx.put_slice(plans, Nx.broadcast(plan, {1,1,3}), [i, j, 0])
              {i, j + 1, plans, grid}
            else
              {i, j + 1, plans, grid}
            end
          end

        {i + 1, plans, grid}
      end

    plans
  end

  defn create_plan_mock(x, y, grid) do
    {_i, _j, _direction, availability, availability_size, _grid} =
      while {x, y, direction = 1, availability =  Nx.broadcast(Nx.tensor(0), {8}), curr = 0, grid}, Nx.less(direction, 9) do
        {x, y} = shift({x, y}, direction)

        if is_valid({x, y}, grid) do
          {x, y, direction + 1, Nx.put_slice(availability, Nx.broadcast(direction, {1}), [curr]), curr + 1, grid}
        else
          {x, y, direction + 1, availability, curr, grid}
        end
      end

    index = Nx.random_uniform({1}, 0, availability_size, type: {:s, 8})
    # todo to_scalar doesn't work in defn, and tensor([scalar-tensor, scalar, scalar]) doesnt work,
    # so to create [dir, mock, empty] we convert dir (scalar tensor)
    # to tensor of shape [1]
    direction = availability[index]
    direction = Nx.reshape(direction, {1})
    action_consequence = Nx.tensor([@mock, @empty])
    plan = Nx.concatenate([direction, action_consequence])
    plan
  end

  # todo celaner architecture proposition, if nx implements new functions
  def create_plans2(grid) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    plans =  Nx.map(Nx.iota({x_size, y_size}), fn ordinal ->
      create_plan(grid[Nx.quotient(ordinal, y_size)][Nx.remainder(ordinal,y_size)]) end)
  end

  defn create_plan values do
    values[0]
  end

  def process_plans(grid, plans) do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    order = 0..(x_size*y_size-1)
    |> Enum.shuffle
    |> Nx.tensor
    process_plans_in_order(grid, plans, order)
  end

  defn process_plans_in_order(grid, plans, order)do
    {x_size, y_size, _z_size} = Nx.shape(grid)
    {order_len} = Nx.shape(order)
    {_i, _order, _plans, grid, _y_size, accepted_plans} =
      while {i = 0, order, plans, grid, y_size, accepted_plans= Nx.broadcast(0, {x_size, y_size})}, Nx.less(i, order_len) do
          ordinal = order[i]
          {x, y} = {Nx.quotient(ordinal, y_size), Nx.remainder(ordinal, y_size)}
          {grid, accepted_plans} = process_plan(x, y, plans, grid, accepted_plans)
          {i+1, order, plans, grid, y_size, accepted_plans}
      end
    {grid, accepted_plans}
  end

  defn process_plan(x, y, plans, grid, accepted_plans) do
    object = grid[x][y][0]
    if Nx.equal(object, @empty) do
      {grid, accepted_plans}
      else
      {x_target, y_target} = shift({x, y}, plans[x][y][0])
      action = plans[x][y][1]
      consequence = plans[x][y][2]
      if Nx.equal(grid[x_target][y_target][0], @empty) do
        grid = Nx.put_slice(grid, Nx.broadcast(action, {1, 1, 1}), [x_target, y_target, 0])
        grid = Nx.put_slice(grid, Nx.broadcast(consequence, {1, 1, 1}), [x, y, 0])
        accepted_plans = Nx.put_slice(accepted_plans, Nx.broadcast(1, {1, 1}), [x, y])
        {grid, accepted_plans}
        else
        {grid, accepted_plans}
        end
    end
  end

  defn shift({x, y}, direction) do
    cond do
      Nx.equal(direction, @dir_stay) -> {x, y}
      Nx.equal(direction, @dir_top) -> {x-1, y}
      Nx.equal(direction, @dir_top_right) -> {x-1, y+1}
      Nx.equal(direction, @dir_right) -> {x, y+1}
      Nx.equal(direction, @dir_bottom_right) -> {x+1, y+1}
      Nx.equal(direction, @dir_bottom) -> {x+1, y}
      Nx.equal(direction, @dir_bottom_left) -> {x+1, y-1}
      Nx.equal(direction, @dir_left) -> {x, y-1}
      Nx.equal(direction, @dir_top_left) -> {x-1, y-1}
      true -> {0, 0} # todo why? shouldnt throw?
    end
  end

  defn is_valid({x, y}, grid) do
    {x_size, y_size, _} = Nx.shape(grid)
    [Nx.greater_equal(x, 0), Nx.less(x, x_size), Nx.greater_equal(y, 0), Nx.less(y, y_size), Nx.equal(grid[x][y][4], 0)]
    |> Nx.stack()
    |> Nx.all?
  end

#  def create_plan cell_position, cells_by_coords, neighbors_by_coords do
#    case cells_by_coords[cell_position] do
#      :mock -> random_move(cell_position, cells_by_coords, neighbors_by_coords)
#      _     -> {}
#    end
#  end
#
#  @doc """
#  For now abandon 'Alternative' in plans (not appearing in Mock example)
#  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
#  """
#  def random_move cell_position, cells_by_coords, neighbors_by_coords do
#    available_directions =
#      neighbors_by_coords[cell_position]
#      |> Enum.filter(fn {_, position} ->
#        cells_by_coords[position] == :empty end)
#      |> Enum.map(fn {direction, _} -> direction end)
#
#    case available_directions do
#      [] -> {}
#      _  ->
#        direction = Enum.random(available_directions)
#        {{shift(cell_position, direction), :mock}, {cell_position, :empty}}
#    end
#  end
#
#  @doc"""
#  apply action from all accepted plans -> returns {cells_by_coords, accepted_plans}
#"""
#  def process_plans cells_by_coords, plans do
#    process_plans_inner(cells_by_coords, [], plans)
#  end
#
#  def process_plans_inner cells_by_coords, accepted_plans, [] do
#    {cells_by_coords, accepted_plans}
#  end
#
#  def process_plans_inner cells_by_coords, accepted_plans, [plan | plans] do
#    if validate_plan cells_by_coords, plan do
#      {{target, action}, _} = plan
#      process_plans_inner(%{cells_by_coords | target => action}, [plan | accepted_plans], plans)
#    else
#      process_plans_inner(cells_by_coords, accepted_plans, plans)
#    end
#  end
#  @doc"""
#  check if plan can be executed (here: if target field is empty)
#"""
  def validate_plan grid, plans, x, y do
    case plans[x][y] do
      @dir_stay -> true
      dir ->
        {x2, y2} = shift({x,y}, dir)
        grid[x2][y2][0] == @empty
    end
  end
#  @doc"""
#    return cells_by_coords with applied given consequences
#  """
#  def apply_consequences cells_by_coords, [] do
#    cells_by_coords
#  end
#  def apply_consequences cells_by_coord, [consequence | consequences] do
#    {target, action} = consequence
#    apply_consequences(%{cells_by_coord | target => action}, consequences)
#  end
#
#  @doc"""
#  calculate new signals for all cells
#"""
#  def calculate_signal_updates cells_by_coord, neighbors_by_coord, signal_by_coord do
#    all_coords = Map.keys(signal_by_coord)
#    all_coords
#    |> Enum.map(fn coords ->
#      {coords, calculate_signal_update(coords, cells_by_coord, neighbors_by_coord[coords], signal_by_coord)} end)
#    |> Map.new
#  end
#  @doc"""
#    calculate new signal for given coordinates
#    returns map {direction => new_signal}
#  """
#  def calculate_signal_update coords, cells_by_coord, cell_neighbors, signals_by_coord do
#    signals_by_coord[coords]
#    |> Enum.map(fn {direction, _direction_signal} ->
#      {direction, calculate_signal_for_direction(direction, cells_by_coord, Map.get(cell_neighbors, direction, nil), signals_by_coord)} end)
#    |> Map.new
#  end
#  @doc"""
#    calculate signal for given directions
#    returns generated + propagated signal for given direction
#    neighbor_coords - coordinates of a neighbor from direction @direction (e.g. {2,3})
#  """
#  def calculate_signal_for_direction direction, cells_by_coords, neighbor_coords, signal_by_coords do
#    cond do
#      direction in [:top, :right, :bottom, :left] ->
#        case neighbor_coords do
#          nil -> 0
#          _   ->
#            propagated_signal =
#              with_adjacent(direction)
#              |> Enum.map(fn neighbor_direction ->
#                Map.get(signal_by_coords[neighbor_coords], neighbor_direction) end)
#              |> Enum.sum
#
#            generated_signal = generate_signal(cells_by_coords[neighbor_coords])
#
#            propagated_signal + generated_signal
#        end
#      direction in [:top_right, :bottom_right, :bottom_left, :top_left] ->
#        case neighbor_coords do
#          nil -> 0
#          _   -> Map.get(signal_by_coords[neighbor_coords], direction) + generate_signal(cells_by_coords[neighbor_coords])
#        end
#      true -> 0
#    end
#  end
#
#  @doc"""
#    apply signal update for all cells
#  @old_signal: signal from previous iteration
#  @signal_update: generated and propagated signal in this iteration for each cell
#  """
#  def apply_signal_updates old_signal_by_coord, signal_update_by_coord, cells_by_coords do
#    old_signal_by_coord
#    |> Enum.map(fn {coords, cell_signal} ->
#      {coords, apply_signal_update(cell_signal, signal_update_by_coord[coords], signal_factor(cells_by_coords[coords]))} end)
#    |> Map.new
#  end
#
#  @doc"""
#    returns new value of signal per direction for given cell:
#    new signal with suppression factor added to old signal, then attenuated and multiplied by cell_signal_factor
#  """
#  def apply_signal_update old_cell_signal, cell_signal_update, cell_signal_factor do
#    old_cell_signal
#    |> Enum.map(fn {direction, signal} ->
#      {direction,
#        (signal + cell_signal_update[direction] * @signal_suppression_factor) * @signal_attenuation_factor * cell_signal_factor} end)
#    |> Map.new
#  end
  @doc"""
  send each plan to worker managing cells affected by this plan
"""
  def distribute_plans iteration, plans do
    send(self(), {:remote_plans, iteration, plans})
  end
#  @doc"""
#    send each consequence to worker managing cells affected by this plan consequence
#  """
#  def distribute_consequences iteration, consequences do
#    send(self(), {:remote_consequences, iteration, consequences})
#  end
#  @doc"""
#    send each signal to worker managing cells affected by this signal
#  """
#  def distribute_signal iteration, signal_by_coords do
#    send(self(), {:remote_signal, iteration, signal_by_coords})
#  end
end
