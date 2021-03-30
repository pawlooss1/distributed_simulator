defmodule WorkerActor do
  @moduledoc false

  import Cell
  import Position
  import Utils

  @max_iterations 5
  @signal_suppression_factor 0.4
  @signal_attenuation_factor 0.4

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example).
  Currently there is also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def listen cells_by_coords, neighbors_by_coords, signal_by_coords do
    receive do
      {:start_iteration, iteration} when iteration > @max_iterations ->
        IO.puts "terminating worker"

      {:start_iteration, iteration} ->
        plans =
          Map.keys(cells_by_coords)
          |> Enum.map(fn position -> create_plan(position, cells_by_coords, neighbors_by_coords) end)

        distribute_plans(iteration, plans)
        listen(cells_by_coords, neighbors_by_coords, signal_by_coords)

      {:remote_plans, iteration, plans} ->
        {updated_grid, accepted_plans} = process_plans(cells_by_coords, Enum.shuffle(plans))
        consequences = Enum.map(accepted_plans, fn {_, consequence} -> consequence end)

        distribute_consequences(iteration, consequences)
        listen(updated_grid, neighbors_by_coords, signal_by_coords)

      {:remote_consequences, iteration, consequences} ->
        updated_grid = apply_consequences(cells_by_coords, consequences)

        distribute_signal(iteration, calculate_signal_updates(cells_by_coords, neighbors_by_coords, signal_by_coords))
        listen(updated_grid, neighbors_by_coords, signal_by_coords)

      {:remote_signal, iteration, signal_updates} ->
        updated_signal = apply_signal_updates(signal_by_coords, signal_updates, cells_by_coords)
        write_to_file(cells_by_coords, updated_signal, "grid_#{iteration}")

        send(self(), {:start_iteration, iteration + 1})
        listen(cells_by_coords, neighbors_by_coords, updated_signal)
    end
  end

  def create_plan cell_position, cells_by_coords, neighbors_by_coords do
    case cells_by_coords[cell_position] do
      :mock -> random_move(cell_position, cells_by_coords, neighbors_by_coords)
      _     -> {}
    end
  end

  @doc """
  For now abandon 'Alternative' in plans (not appearing in Mock example)
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def random_move cell_position, cells_by_coords, neighbors_by_coords do
    available_directions =
      neighbors_by_coords[cell_position]
      |> Enum.filter(fn {_, position} ->
        cells_by_coords[position] == :empty end)
      |> Enum.map(fn {direction, _} -> direction end)

    case available_directions do
      [] -> {}
      _  ->
        direction = Enum.random(available_directions)
        {{shift(cell_position, direction), :mock}, {cell_position, :empty}}
    end
  end

  @doc"""
  apply action from all accepted plans -> returns {cells_by_coords, accepted_plans}
"""
  def process_plans cells_by_coords, plans do
    process_plans_inner(cells_by_coords, [], plans)
  end

  def process_plans_inner cells_by_coords, accepted_plans, [] do
    {cells_by_coords, accepted_plans}
  end

  def process_plans_inner cells_by_coords, accepted_plans, [plan | plans] do
    if validate_plan cells_by_coords, plan do
      {{target, action}, _} = plan
      process_plans_inner(%{cells_by_coords | target => action}, [plan | accepted_plans], plans)
    else
      process_plans_inner(cells_by_coords, accepted_plans, plans)
    end
  end
  @doc"""
  check if plan can be executed (here: if target field is empty)
"""
  def validate_plan cells_by_coords, plan do
    case plan do
      {}               -> false
      {{target, _}, _} -> cells_by_coords[target] == :empty
    end
  end
  @doc"""
    return cells_by_coords with applied given consequences
  """
  def apply_consequences cells_by_coords, [] do
    cells_by_coords
  end
  def apply_consequences cells_by_coord, [consequence | consequences] do
    {target, action} = consequence
    apply_consequences(%{cells_by_coord | target => action}, consequences)
  end

  @doc"""
  calculate new signals for all cells
"""
  def calculate_signal_updates cells_by_coord, neighbors_by_coord, signal_by_coord do
    all_coords = Map.keys(signal_by_coord)
    all_coords
    |> Enum.map(fn coords ->
      {coords, calculate_signal_update(coords, cells_by_coord, neighbors_by_coord[coords], signal_by_coord)} end)
    |> Map.new
  end
  @doc"""
    calculate new signal for given coordinates
    returns map {direction => new_signal}
  """
  def calculate_signal_update coords, cells_by_coord, cell_neighbors, signals_by_coord do
    signals_by_coord[coords]
    |> Enum.map(fn {direction, _direction_signal} ->
      {direction, calculate_signal_for_direction(direction, cells_by_coord, Map.get(cell_neighbors, direction, nil), signals_by_coord)} end)
    |> Map.new
  end
  @doc"""
    calculate signal for given directions
    returns generated + propagated signal for given direction
    neighbor_coords - coordinates of a neighbor from direction @direction (e.g. {2,3})
  """
  def calculate_signal_for_direction direction, cells_by_coords, neighbor_coords, signal_by_coords do
    cond do
      direction in [:top, :right, :bottom, :left] ->
        case neighbor_coords do
          nil -> 0
          _   ->
            propagated_signal =
              with_adjacent(direction)
              |> Enum.map(fn neighbor_direction ->
                Map.get(signal_by_coords[neighbor_coords], neighbor_direction) end)
              |> Enum.sum

            generated_signal = generate_signal(cells_by_coords[neighbor_coords])

            propagated_signal + generated_signal
        end
      direction in [:top_right, :bottom_right, :bottom_left, :top_left] ->
        case neighbor_coords do
          nil -> 0
          _   -> Map.get(signal_by_coords[neighbor_coords], direction) + generate_signal(cells_by_coords[neighbor_coords])
        end
      true -> 0
    end
  end

  @doc"""
    apply signal update for all cells
  @old_signal: signal from previous iteration
  @signal_update: generated and propagated signal in this iteration for each cell
  """
  def apply_signal_updates old_signal_by_coord, signal_update_by_coord, cells_by_coords do
    old_signal_by_coord
    |> Enum.map(fn {coords, cell_signal} ->
      {coords, apply_signal_update(cell_signal, signal_update_by_coord[coords], signal_factor(cells_by_coords[coords]))} end)
    |> Map.new
  end

  @doc"""
    returns new value of signal per direction for given cell:
    new signal with suppression factor added to old signal, then attenuated and multiplied by cell_signal_factor
  """
  def apply_signal_update old_cell_signal, cell_signal_update, cell_signal_factor do
    old_cell_signal
    |> Enum.map(fn {direction, signal} ->
      {direction,
        (signal + cell_signal_update[direction] * @signal_suppression_factor) * @signal_attenuation_factor * cell_signal_factor} end)
    |> Map.new
  end
  @doc"""
  send each plan to worker managing cells affected by this plan
"""
  def distribute_plans iteration, plans do
    send(self(), {:remote_plans, iteration, plans})
  end
  @doc"""
    send each consequence to worker managing cells affected by this plan consequence
  """
  def distribute_consequences iteration, consequences do
    send(self(), {:remote_consequences, iteration, consequences})
  end
  @doc"""
    send each signal to worker managing cells affected by this signal
  """
  def distribute_signal iteration, signal_by_coords do
    send(self(), {:remote_signal, iteration, signal_by_coords})
  end
end
