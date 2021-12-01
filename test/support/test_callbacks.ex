defmodule Simulator.TestCallbacks do
  @moduledoc """
  There are helper functions that mocks simulation callbacks. They 
  are meant to be very simple.
  """

  use Simulator.TestConstants

  import Nx.Defn
  import Simulator.Helpers

  defn create_plan(i, j, _plans, grid, _objects_state, _iteration) do
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

  defn is_update_valid?(action, object) do
    cond do
      both_equal(action, @add_1, object, @empty) -> Nx.tensor(1)
      both_equal(action, @remove_2, object, @object_2) -> Nx.tensor(1)
      true -> Nx.tensor(0)
    end
  end

  defn apply_action(object, plan, old_state) do
    {new_object, new_state} =
      cond do
        plans_objects_match(plan, @move, object, @empty) -> {@object_1, old_state - 1}
        plans_objects_match(plan, @destroy, object, @object_2) -> {@empty, old_state}
        true -> {object, old_state}
      end

    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  defn apply_consequence(object, plan, old_state) do
    {new_object, new_state} =
      cond do
        plans_objects_match(plan, @move, object, @object_1) -> {@empty, 0}
        plans_objects_match(plan, @destroy, object, @empty) -> {@empty, old_state}
        :otherwise -> {object, old_state}
      end

    {new_object, Nx.broadcast(new_state, {1, 1})}
  end

  defn generate_signal(object) do
    cond do
      Nx.equal(object, @object_1) -> 10
      Nx.equal(object, @object_2) -> -10
      true -> 0
    end
  end

  defn signal_factor(object) do
    cond do
      Nx.equal(object, @object_2) -> 2
      true -> 1
    end
  end
end
