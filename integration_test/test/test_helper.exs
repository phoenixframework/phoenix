# Copy _build/test to _build/dev so it only has to be compiled once
File.rm_rf!(Path.expand("../_build/dev", __DIR__))

File.cp_r!(
  Path.expand("../_build/test", __DIR__),
  Path.expand("../_build/dev", __DIR__)
)

ExUnit.configure(timeout: 180_000, exclude: [:database])
ExUnit.start()
