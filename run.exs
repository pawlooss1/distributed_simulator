alias Simulator.Launcher
mode = Application.fetch_env!(:distributed_simulator, :mode)
:ok = Launcher.start(mode)