defmodule Simulator.WorkerActor.Signal do
  @moduledoc """
  Module contataining Worker's functions responsible for the signal.
  """

  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  @doc """
  Calculates signal update for all cells.
  """
  @spec calculate_signal_updates(Nx.t(), fun()) :: Nx.t()
  defn calculate_signal_updates(grid, generate_signal) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, update_grid} =
      while {i = 1, grid, update_grid = Nx.broadcast(0, Nx.shape(grid))},
            Nx.less(i, x_size - 1) do
        update_for_row = Nx.broadcast(0, {y_size, 8})

        {_i, _j, grid, update_for_row} =
          while {i, j = 1, grid, update_for_row}, Nx.less(j, y_size - 1) do
            update_for_cell = signal_update_for_cell(i, j, grid, generate_signal)

            update_for_row =
              Nx.put_slice(update_for_row, [j, 1], Nx.broadcast(update_for_cell, {1, 8}))

            {i, j + 1, grid, update_for_row}
          end

        update_grid =
          Nx.put_slice(update_grid, [i, 1, 1], Nx.broadcast(update_for_row, {1, y_size, 8}))

        {i + 1, grid, update_grid}
      end

    update_grid
  end

  # Standard signal update for given cell.
  defnp signal_update_for_cell(x, y, grid, generate_signal) do
    signals_update = Nx.broadcast(0, {8})

    {_x, _y, _dir, _grid, signals_update} =
      while {x, y, dir = 1, grid, signals_update}, Nx.less(dir, 9) do
        # coords of a cell that we consider signal from
        {x2, y2} = shift({x, y}, dir)

        if is_valid({x2, y2}, grid) do
          update_value = signal_update_from_direction(x2, y2, grid, dir, generate_signal)

          signals_update =
            Nx.put_slice(signals_update, [dir - 1], Nx.broadcast(update_value, {1}))

          {x, y, dir + 1, grid, signals_update}
        else
          {x, y, dir + 1, grid, signals_update}
        end
      end

    signals_update
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

  @doc """
  Applies signal update.

  Cuts out only signal (without object) from `grid` and
  `signal_update`, performs applying update and puts result back to
  the `grid`.

  Applying update is making such an operation on every signal value
  {i, j, dir}:
  s[i][j][dir] = (s[i][j][dir] + S * u[i][j][dir]) * A * f(g[i][j][0])
  where:
  - s - a signal grid (3D tensor cut out from `grid`);
  - u - passed `signal update` (3D tensor);
  - g - passed `grid`;
  - S - `@signal_suppression_factor`;
  - A - `@signal_attenuation_factor`;
  - f - `signal_factor` function - returned value depends on the
    contents of the cell.
  """
  @spec apply_signal_update(Nx.t(), Nx.t(), fun()) :: Nx.t()
  defn apply_signal_update(grid, signal_update, signal_factor) do
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

    Nx.put_slice(grid, [0, 0, 1], updated_signal)
  end

  # Returns 3D tensor with shape {x, y, 1}, where {x, y, _z} is a
  # shape of the passed `grid`. Tensor gives a factor for every cell
  # to multiply it by signal in that cell. Value depends on the
  # contents of the cell - e.g. obstacles block the signal.
  defnp map_signal_factor(grid, signal_factor) do
    {x_size, y_size, _z_size} = Nx.shape(grid)

    {_i, _grid, signal_factors} =
      while {i = 0, grid, signal_factors = Nx.broadcast(0, {x_size, y_size, 1})},
            Nx.less(i, x_size) do
        {_i, _j, grid, signal_factors} =
          while {i, j = 0, grid, signal_factors}, Nx.less(j, y_size) do
            cell_signal_factor = Nx.broadcast(signal_factor.(grid[i][j][0]), {1, 1, 1})
            signal_factors = Nx.put_slice(signal_factors, [i, j, 0], cell_signal_factor)

            {i, j + 1, grid, signal_factors}
          end

        {i + 1, grid, signal_factors}
      end

    signal_factors
  end

  # gets next direction, counterclockwise ( @top -> @top_left, @right -> @bottom_right)
  defnp adj_left(dir) do
    Nx.remainder(8 + dir - 2, 8) + 1
  end

  # gets next direction, clockwise (@top -> @top_right, @top_left -> @top)
  defnp adj_right(dir) do
    Nx.remainder(dir, 8) + 1
  end
end
