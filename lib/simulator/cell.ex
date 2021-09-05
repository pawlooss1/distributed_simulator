defmodule Simulator.Cell do
  @moduledoc false

  @callback generate_signal(non_neg_integer()) :: non_neg_integer()
  @callback signal_factor(non_neg_integer()) :: non_neg_integer()
end
