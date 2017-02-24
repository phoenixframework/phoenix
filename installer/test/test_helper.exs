ExUnit.start()

# TODO: Remove this when Elixir v1.3 is no longer supported
if Version.match?(System.version, "~> 1.3.0") do
  System.halt(0)
end
