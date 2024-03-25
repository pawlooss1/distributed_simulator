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
  defn calculate_signal_updates(grid, signal_generators) do
    propagated_signals = propagate_signals(grid)
    generated_signals = generate_signals(grid, signal_generators)
    propagated_signals + generated_signals
  end

  defn propagate_signals(grid) do
    {_, _, update} =
    while {direction = 1, grid, updated_grid = grid}, direction < 9 do
      update = propagated_signals_for_direction(grid, direction)
      {direction + 1, grid, Nx.put_slice(updated_grid, [0, 0, direction], add_dimension(update))}
    end
    update[[.., .., 1..-1//1]]
  end

  defn generate_signals(grid, signal_generators) do
    generators = signal_generators.()
    {n, _} = Nx.shape(generators)

    {_, _, _, signal_update} =
      while {
              i = 0,
              generators,
              g = grid[[.., .., 0]],
              signal_update = Nx.broadcast(0, Nx.shape(grid)),
            },
            i < n do
        filter = generators[i][0]
        generated_signal = generators[i][1]

        filtered_g = g == filter
        u_o = filtered_g * generated_signal

        {i + 1, generators, g, signal_update + Nx.broadcast(u_o, grid, axes: [0, 1])}
      end

    signal_update[[.., .., 1..-1//1]]
  end

  defn propagated_signals_for_direction(grid, direction) do
    if rem(direction, 2) do
      Nx.sum(Nx.stack([
        signal_shift(grid[[.., .., adj_left(direction)]], direction),
        signal_shift(grid[[.., .., direction]], direction),
        signal_shift(grid[[.., .., adj_right(direction)]], direction)
      ], axis: 2), axes: [2])
    else
      signal_shift(grid[[.., .., direction]], direction)
    end
  end

  defn signal_shift(grid, direction) do
    padded_grid = Nx.pad(grid, 0, [{1, 1, 0}, {1, 1, 0}])
    cond do
      direction == 1 -> padded_grid[[1..-2//1, 2..-1//1]]
      direction == 2 -> padded_grid[[0..-3//1, 2..-1//1]]
      direction == 3 -> padded_grid[[0..-3//1, 1..-2//1]]
      direction == 4 -> padded_grid[[0..-3//1, 0..-3//1]]
      direction == 5 -> padded_grid[[1..-2//1, 0..-3//1]]
      direction == 6 -> padded_grid[[2..-1//1, 0..-3//1]]
      direction == 7 -> padded_grid[[2..-1//1, 1..-2//1]]
      direction == 8 -> padded_grid[[2..-1//1, 2..-1//1]]
      # we should never get here
      true -> grid
    end
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
  defn apply_signal_update(grid, signal_update, signal_factors) do
    cell_factors = map_signal_factor(grid, signal_factors)

    signal = Nx.slice_along_axis(grid, 1, 8, [axis: 2])

    updated_signal =
      signal_update
      |> Nx.multiply(@signal_suppression_factor)
      |> Nx.add(signal)
      |> Nx.multiply(@signal_attenuation_factor)
      |> Nx.multiply(cell_factors)
      |> Nx.round()
      |> Nx.as_type(@grid_type)

    Nx.put_slice(grid, [0, 0, 1], updated_signal)
  end

  # Returns 3D tensor with shape {x, y, 1}, where {x, y, _z} is a
  # shape of the passed `grid`. Tensor gives a factor for every cell
  # to multiply it by signal in that cell. Value depends on the
  # contents of the cell - e.g. obstacles block the signal.
  defn map_signal_factor(grid, signal_factors) do
    factors = signal_factors.()
    {n, _} = Nx.shape(factors)
    {x, y, _} = Nx.shape(grid)
    g = grid[[.., .., 0]]

    {_, _, _, cell_factors, updated_cells} =
      while {
              i = 0,
              factors,
              g,
              cell_factors = Nx.broadcast(0.0, Nx.shape(g)),
              updated_cells = Nx.broadcast(0, Nx.shape(g))
            },
            i < n do
        filter = factors[i][0]
        factor = factors[i][1]

        filtered_g = g == filter
        cell_factor = filtered_g * factor

        {i + 1, factors, g, cell_factors + cell_factor, updated_cells + filtered_g}
      end

    unmodified_cells = not updated_cells
    add_dimension(unmodified_cells + cell_factors)
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
