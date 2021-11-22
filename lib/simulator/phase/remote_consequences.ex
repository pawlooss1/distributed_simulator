defmodule Simulator.Phase.RemoteConsequences do
  @moduledoc """
  Module contataining the functions called during the
  `:remote_consequences` phase.
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

  @doc """
  Calculates signal update for all cells.
  """
  @spec calculate_signal_updates(Nx.t(), fun()) :: Nx.t()
  defn calculate_signal_updates(grid, generate_signal) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, update_grid} =
      while {i = 1, grid, update_grid = Nx.broadcast(0, Nx.shape(grid))}, Nx.less(i, x_size - 1) do
        {_i, _j, grid, update_grid} =
          while {i, j = 1, grid, update_grid}, Nx.less(j, y_size - 1) do
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
            Nx.put_slice(update_grid, [x, y, dir], Nx.broadcast(update_value, {1, 1, 1}))

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
end
