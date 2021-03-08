defmodule DistributedSimulatorTest do
  use ExUnit.Case
  doctest DistributedSimulator

  test "greets the world" do
    assert DistributedSimulator.hello() == :world
  end
end
