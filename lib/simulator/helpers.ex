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
      [0, 1],
      [-1, 1],
      [-1, 0],
      [-1, -1],
      [0, -1],
      [1, -1],
      [1, 0],
      [1, 1],
    ])
    direction = direction >>> @direction_position
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

  @spec calc_plan_directions(Nx.t()) :: Nx.t()
  defn calc_plan_directions(grid) do
    resultants = Nx.dot(grid[[.., .., 1..8]], @direction_vectors)

    resultants
    |> Nx.phase()
    |> radian_to_direction()
    # 0 + i0 has angle = 0 too hence the correction
    |> Nx.multiply(resultants != Nx.complex(0, 0))
    |> Nx.as_type(Nx.type(grid))
  end

  defnp radian_to_direction(angles) do
    Nx.round(angles * 4 / Nx.Constants.pi())
    # correction because Nx.phase results are from (-pi, pi]
    |> Nx.add(8)
    |> Nx.remainder(8)
    # angle = 0 -> dir = 1, etc.
    |> Nx.add(1)
  end

  @spec create_plans_for_object_type(Nx.t(), Nx.t(), Nx.t(), Nx.t(), Nx.t()) :: Nx.t()
  defn create_plans_for_object_type(grid, objects_state, directions, plan, object_filter) do
    directions = object_filter.(grid, objects_state) * directions
    filter = directions != 0
    plans = filter * plan
    plans + (directions <<< @direction_position)
  end

  @spec create_plans_without_dir_for_object_type(Nx.t(), Nx.t(), Nx.t(), Nx.t()) :: Nx.t()
  defn create_plans_without_dir_for_object_type(grid, objects_state, plan, object_filter) do
    object_filter.(grid, objects_state) * plan
  end

  @spec choose_available_directions_randomly(Nx.t(), Nx.t(), Nx.t()) :: {Nx.t(), Nx.t()}
  defn choose_available_directions_randomly(grid, rng, availability_filter) do
    {x, y} = Nx.shape(grid)
    {r, rng} = Nx.Random.uniform(rng, shape: {x, y, 8})
    available_fields = availability_filter.(grid)
    available_neighbourhood = attach_neighbourhood_to_new_dim(available_fields)
    directions = Nx.argmax(available_neighbourhood[[.., .., 1..-1//1]] * r, axis: 2) + 1
    {directions, rng}
  end
end
