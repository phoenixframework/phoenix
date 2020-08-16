Code.require_file("./support/mix_task_runner.exs", __DIR__)

# Compile installer app up front so multiple test cases
# don't try to compile it at the same time.
Phoenix.Integration.MixTaskRunner.run!(["do", "deps.get,", "compile"], cd: "./installer")

ExUnit.configure(max_cases: 2, timeout: 180_000)
ExUnit.start()
