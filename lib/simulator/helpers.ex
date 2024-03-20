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
    shifts = Nx.tensor([
      [0, 0],
      [-1, 0],
      [-1, 1],
      [0, 1],
      [1, 1],
      [1, 0],
      [1, -1],
      [0, -1],
      [-1, -1]
    ])
    shift = shifts[direction]
    {x + shift[0], y + shift[1]}
  end

  @doc """
  Returns opposite directions from the given argument.
  """
  @spec opposite(Nx.t()) :: Nx.t()
  defn opposite(direction) do
    cond do
      Nx.equal(direction, @dir_stay) -> @dir_stay
      Nx.equal(direction, @dir_top) -> @dir_bottom
      Nx.equal(direction, @dir_top_right) -> @dir_bottom_left
      Nx.equal(direction, @dir_right) -> @dir_left
      Nx.equal(direction, @dir_bottom_right) -> @dir_top_left
      Nx.equal(direction, @dir_bottom) -> @dir_top
      Nx.equal(direction, @dir_bottom_left) -> @dir_top_right
      Nx.equal(direction, @dir_left) -> @dir_right
      Nx.equal(direction, @dir_top_left) -> @dir_bottom_right
      true -> @dir_stay
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

  @spec identity(Nx.t) :: Nx.t()
  defn identity(tensor) do
    tensor
  end

  @spec add_dimension(Nx.t()) :: Nx.t()
  defn add_dimension(tensor) do
    Nx.new_axis(tensor, -1)
  end

  @spec attach_neighbourhood_to_new_dim(Nx.t()) :: Nx.t()
  defn attach_neighbourhood_to_new_dim(grid) do
    padded_grid = Nx.pad(grid, 0, [{1, 1, 0}, {1, 1, 0}])
    Nx.stack([
      grid,
      padded_grid[[1..-2//1, 2..-1//1]],
      padded_grid[[0..-3//1, 2..-1//1]],
      padded_grid[[0..-3//1, 1..-2//1]],
      padded_grid[[0..-3//1, 0..-3//1]],
      padded_grid[[1..-2//1, 0..-3//1]],
      padded_grid[[2..-1//1, 0..-3//1]],
      padded_grid[[2..-1//1, 1..-2//1]],
      padded_grid[[2..-1//1, 2..-1//1]],
    ], axis: 2)
  end
end
