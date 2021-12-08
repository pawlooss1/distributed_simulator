defmodule Simulator.ScenarioElements do
  @moduledoc """
  Module containing structures used in test scenario.
  """

  use Simulator.TestConstants

  #   _ _ _ _ _
  # |   1 1     |
  # | 2     2   |
  # | _ _ _ _ 2 |
  @grid [
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

  @plans [
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

  @objects_state [
                   [0, 0, 0, 0, 0, 0],
                   [0, 0, 10, 6, 0, 0],
                   [0, 0, 0, 0, 0, 0],
                   [0, 0, 0, 0, 0, 0],
                   [0, 0, 0, 0, 0, 0]
                 ]
                 |> Nx.tensor()

  def grid(), do: @grid

  def plans(), do: @plans

  def objects_state(), do: @objects_state
end
