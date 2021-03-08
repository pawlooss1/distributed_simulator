defmodule WorldConfig do
  @moduledoc false
  use TypedStruct
  typedstruct do
      field :worldType, String.t()
      field :worldWidth, non_neg_integer()
      field :worldHeight, non_neg_integer()
      field :iterationsNumber, non_neg_integer()

      field :signalSuppressionFactor, float()
      field :signalAttenuationFactor, float()
      field :signalSpeedRatio, non_neg_integer()

      field :workersRoot, integer() # todo non neg?
      field :isSupervisor, boolean()
      field :shardingMod, integer()

      field :guiType, nil # todo GuiType
      field :guiCellSize, non_neg_integer()
  end

end
