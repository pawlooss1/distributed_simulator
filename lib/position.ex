defmodule Position do
  @moduledoc false

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

  def sum {x1, y1}, {x2, y2} do
    {x1 + x2, y1 + y2}
  end

  def shift coord, direction do
    sum(coord, get_shift(direction))
  end

  def with_adjacent direction do
    index = Enum.find_index(@directions, &(&1 == direction))
    len = length(@directions)

    [Enum.fetch!(@directions, rem(len + index - 1, len)),
     direction,
     Enum.fetch!(@directions, rem(index + 1, len))]
  end
end
