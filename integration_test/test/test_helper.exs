# Copy _build/test to _build/dev so it only has to be compiled once
File.rm_rf!(Path.expand("../_build/dev", __DIR__))

File.cp_r!(
  Path.expand("../_build/test", __DIR__),
  Path.expand("../_build/dev", __DIR__)
)

# Prevent typos in `@tag database: ...` causing tests to be silently ignored.
Path.wildcard(Path.join(__DIR__, "**/*_test.exs"))
|> Phoenix.Integration.DatabaseTagValidator.validate!()

ExUnit.start(timeout: 180_000, exclude: [:database])
