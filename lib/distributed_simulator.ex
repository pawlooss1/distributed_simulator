defmodule DistributedSimulator do
  @moduledoc """
  Documentation for `DistributedSimulator`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> DistributedSimulator.hello()
      :world

  """
  @x_size 3
  @y_size 4
  @directions [:top, :top_right, :right, :bottom_right, :bottom, :bottom_left, :left, :top_left]

  def get_shift direction do
    case direction do
      :top -> {-1, 0}
      :top_right -> {-1, 1}
      :right -> {0, 1}
      :bottom_right -> {1, 1}
      :bottom -> {1, 0}
      :bottom_left -> {1, -1}
      :left -> {0, -1}
      :top_left -> {-1, -1}
      _ -> direction
    end
  end

  def sum {x1, y1}, coords2 do
    {x2, y2} = get_shift coords2
    {x1 + x2, y1 + y2}
  end

  def is_valid {x, y} do
    x >= 1 and x <= @x_size and y >= 1 and y <= @y_size
  end

  def make_grid do
    cells = for k_x <- 1..@x_size, k_y <- 1..@y_size, into: %{}, do: {{k_x, k_y}, %Cell{id: (k_x-1)*@y_size + k_y}}
    neighbors = cells
      |> Enum.map(fn {coords, _} -> {coords,
                         (for direction <- @directions, is_valid(sum(coords, direction)), into: %{}, do: {direction, sum(coords, direction)})} end)
      |> Map.new

    {cells, neighbors}
  end

  def hello do
    make_grid()
  end
end
