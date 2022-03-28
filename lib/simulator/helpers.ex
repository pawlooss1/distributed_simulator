defmodule Simulator.Helpers do
  @moduledoc """
  Module containing useful functions (numerical definitions).
  """

  use Simulator.BaseConstants

  import Nx.Defn

  alias Simulator.Types

  @doc """
  Returns coordinates of the cell being in `direction` from the given `{x, y}`.
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
      true -> {0, 0}
    end
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
    |> Nx.all()
  end

  @doc """
  Checks whether `a == a_ref and b == b_ref`.
  """
  @spec both_equal(Nx.t(), Nx.t(), Nx.t(), Nx.t()) :: Nx.t()
  defn both_equal(a, a_ref, b, b_ref) do
    [Nx.equal(a, a_ref), Nx.equal(b, b_ref)]
    |> Nx.stack()
    |> Nx.all()
  end

  @doc """
  Checks whether `plan_a == plan_b and object_a == object_b`.
  """
  @spec plans_objects_match(Nx.t(), Nx.t(), Nx.t(), Nx.t()) :: Nx.t()
  defn plans_objects_match(plan_a, plan_b, object_a, object_b) do
    plans_match(plan_a, plan_b) and Nx.equal(object_a, object_b)
  end

  @doc """
  Checks whether `plan_a == plan_b`.
  """
  @spec plans_match(Nx.t(), Nx.t()) :: Nx.t()
  defn plans_match(plan_a, plan_b) do
    Nx.all(Nx.equal(plan_a, plan_b))
  end

  @doc """
  Puts `object` to the `grid[x][y][0]`.
  """
  @spec put_object(Nx.t(), Types.index(), Types.index(), Nx.t()) :: Nx.t()
  defn put_object(grid, x, y, object) do
    Nx.put_slice(grid, [x, y, 0], Nx.broadcast(object, {1, 1, 1}))
  end
end
