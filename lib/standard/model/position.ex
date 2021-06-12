defmodule Simulator.Standard.Position do
  @moduledoc false

  @directions [:top, :top_right, :right, :bottom_right, :bottom, :bottom_left, :left, :top_left]

  def to_coords direction do
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

  @doc"""
  returns coordinates shifted by direction, e.g :
  {1,2}, :top -> {1,3}
  """
  def shift coord, direction do
    sum(coord, to_coords(direction))
  end

  @doc"""
  returns given direction with its adjacent directions, e.g:
  :top -> [:top_left, :top, :top_right]
  """
  def with_adjacent direction do
    index = Enum.find_index(@directions, &(&1 == direction))
    len = length(@directions)

    [Enum.fetch!(@directions, rem(len + index - 1, len)),
     direction,
     Enum.fetch!(@directions, rem(index + 1, len))]
  end
end
