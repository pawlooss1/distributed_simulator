defmodule Position do
  @moduledoc false

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
end
