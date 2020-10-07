# Copy _build/test to _build/dev so it only has to be compiled once
File.rm_rf!(Path.expand("../_build/dev", __DIR__))

File.cp_r!(
  Path.expand("../_build/test", __DIR__),
  Path.expand("../_build/dev", __DIR__)
)


ExUnit.configure(max_cases: 2, timeout: 180_000)
ExUnit.start()
