Code.require_file "plug_helper.exs", __DIR__
Logger.configure(level: :debug)
Logger.configure_backend(:console, colors: [enabled: false])
Mix.shell(Mix.Shell.Process)
ExUnit.start
