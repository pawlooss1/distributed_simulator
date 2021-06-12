defmodule Simulator.Standard.Cell do
  @moduledoc false
#  todo add iteration and config as parameters (not basic functionality)
  @mock_initial_signal 1

  def generate_signal :mock do
    @mock_initial_signal
  end
  def generate_signal _any do
    0
  end

  def signal_factor :obstacle do
    0
  end
  def signal_factor _any do
    1
  end
end
