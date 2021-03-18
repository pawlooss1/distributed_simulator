defmodule Cell do
  @moduledoc false
#  todo add iteration and config as paramters (not basic functionality)
  def generateSignal _any do 0 end

  def signalFactor :obstacle do 0 end
  def signalFactor _any do 1 end
end
