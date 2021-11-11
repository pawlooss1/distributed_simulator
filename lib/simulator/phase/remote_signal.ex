defmodule Simulator.Phase.RemoteSignal do
  @moduledoc """
  Module contataining the functions called during the
  `:remote_signal` phase.
  """

  use Simulator.BaseConstants

  import Nx.Defn

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

  TODO currently it truncates signal values if they are not integers.
    We can consider rounding them instead.
  """
  @defn_compiler {EXLA, client: :default}
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
end
