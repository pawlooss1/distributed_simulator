defmodule Simulator.Helpers do
  @moduledoc """
  Module containing useful functions (`defn`s).
  """

  use Simulator.BaseConstants

  import Nx.Defn

  alias Simulator.Types

  @doc """
  Returns coordinates of the cell being in `direction` from the given {`x`, `y`}.
  """
  @spec shift({Types.index(), Types.index()}, Nx.t()) :: {Types.index(), Types.index()}
  defn shift({x, y}, direction) do
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
      # TODO why? shouldn't throw? // I think we cannot throw from defn. Any suggestions what to do with that?
      true -> {0, 0}
    end
  end

  @doc """
  Checks whether the mock can move to position {x, y}.
  """
  @spec can_move({Types.index(), Types.index()}, Nx.t()) :: Nx.t()
  defn can_move({x, y}, grid) do
    [is_valid({x, y}, grid), Nx.equal(grid[x][y][0], 0)]
    |> Nx.stack()
    |> Nx.all?()
  end

  @doc """
  Checks if position {x, y} is inside the grid.
  """
  @spec is_valid({Types.index(), Types.index()}, Nx.t()) :: Nx.t()
  defn is_valid({x, y}, grid) do
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
end
