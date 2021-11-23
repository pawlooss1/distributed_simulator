defmodule Simulator.WorkerActor.PlansTest do
  use ExUnit.Case, async: true
  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  alias Simulator.WorkerActor.Plans

  @object_1 1
  @object_2 2

  @add_1 1
  @remove_1 2
  @remove_2 3

  @move Nx.tensor([@add_1, @remove_1])
  @destroy Nx.tensor([@remove_2, @keep])

  @full_plan_keep [@dir_stay, @keep, @keep]

  test "create_plans/4 creates plan correctly" do
    #   _ _ _ _ _
    # |   1 1     |
    # | 2     2   |
    # | _ _ _ _ 2 |
    grid =
      [
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@object_1, 0, 0, 1, 2, 4, 3, 2, 0],
          [@object_1, 0, 0, 5, 4, 3, 2, 6, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@object_2, 1, 2, 0, 1, 1, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@object_2, 5, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@object_2, 3, 0, 0, 0, 0, 0, 3, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ]
      ]
      |> Nx.tensor()

    expected_plans =
      [
        [
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep
        ],
        [
          @full_plan_keep,
          @full_plan_keep,
          [@dir_bottom, @add_1, @remove_1],
          [@dir_right, @add_1, @remove_1],
          @full_plan_keep,
          @full_plan_keep
        ],
        [
          @full_plan_keep,
          [@dir_stay, @remove_2, @keep],
          @full_plan_keep,
          [@dir_stay, @remove_2, @keep],
          @full_plan_keep,
          @full_plan_keep
        ],
        [
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep
        ],
        [
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep,
          @full_plan_keep
        ]
      ]
      |> Nx.tensor()

    plans = Plans.create_plans(0, grid, 0, &create_plan/6)

    assert plans == expected_plans
  end

  defnp create_plan(i, j, _plans, grid, _objects_state, _iteration) do
    cond do
      Nx.equal(grid[i][j][0], @object_1) ->
        create_plan_object_1(i, j, grid)

      Nx.equal(grid[i][j][0], @object_2) ->
        create_plan_object_2(i, j, grid)

      :otherwise ->
        create_plan_other(i, j, grid)
    end
  end

  defnp create_plan_object_1(i, j, grid) do
    {_i, _j, _direction, signals, _grid} =
      while {i, j, direction = @dir_top, signals = Nx.broadcast(Nx.tensor(-@infinity), {9}),
             grid},
            Nx.less_equal(direction, @dir_top_left) do
        {x, y} = shift({i, j}, direction)

        signals =
          if Nx.equal(grid[x][y][0], @empty) do
            Nx.put_slice(signals, [direction], Nx.broadcast(grid[i][j][direction], {1}))
          else
            Nx.put_slice(signals, [direction], Nx.broadcast(-@infinity, {1}))
          end

        {i, j, direction + 1, signals, grid}
      end

    if signals |> Nx.reduce_max() |> Nx.greater(-@infinity) do
      direction = Nx.argmax(signals)
      {direction, @move}
    else
      {@dir_stay, @plan_keep}
    end
  end

  defnp create_plan_object_2(i, j, grid) do
    {_i, _j, _direction, signal_sum, _grid} =
      while {i, j, direction = @dir_top, signal_sum = Nx.tensor(0), grid},
            Nx.less_equal(direction, @dir_top_left) do
        signal_sum = Nx.add(signal_sum, grid[i][j][direction])
        {i, j, direction + 1, signal_sum, grid}
      end

    if Nx.equal(signal_sum, Nx.tensor(5)) do
      {@dir_stay, @destroy}
    else
      {@dir_stay, @plan_keep}
    end
  end

  defnp create_plan_other(_i, _j, _grid) do
    {@dir_stay, @plan_keep}
  end
end
