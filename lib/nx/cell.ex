defmodule Cell do
  @moduledoc false

  import Nx.Defn
  #  todo add iteration and config as parameters (not basic functionality)
  @mock_initial_signal 100

  # todo repeated, in future import
  @mock 1
  @obstacle 2
  #  @empty 0

#  def generate_signal :mock do  todo cannot compile defn with multiple clauses
#    @mock_initial_signal
#  end
#  def generate_signal _any do
#    0
#  end
#
#  def signal_factor :obstacle do
#    0
#  end
#  def signal_factor _any do
#    1
#  end

  defn generate_signal(object) do
    cond do
      Nx.equal(object, @mock) -> @mock_initial_signal
      :otherwise -> 0
    end
  end

  defn signal_factor(object) do
    cond do
      Nx.equal(object, @obstacle) -> 0
      :otherwise -> 1
    end
  end
end
