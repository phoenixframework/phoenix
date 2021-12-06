defmodule Mix.Tasks.Phx.Gen.Auth.HashingLibrary do
  @moduledoc false

  defstruct [:name, :module, :mix_dependency, :test_config]

  def build("bcrypt") do
    lib = %__MODULE__{
      name: :bcrypt,
      module: Bcrypt,
      mix_dependency: ~s|{:bcrypt_elixir, "~> 2.0"}|,
      test_config: """
      config :bcrypt_elixir, :log_rounds, 1
      """
    }

    {:ok, lib}
  end

  def build("pbkdf2") do
    lib = %__MODULE__{
      name: :pbkdf2,
      module: Pbkdf2,
      mix_dependency: ~s|{:pbkdf2_elixir, "~> 1.0"}|,
      test_config: """
      config :pbkdf2_elixir, :rounds, 1
      """
    }

    {:ok, lib}
  end

  def build("argon2") do
    lib = %__MODULE__{
      name: :argon2,
      module: Argon2,
      mix_dependency: ~s|{:argon2_elixir, "~> 2.0"}|,
      test_config: """
      config :argon2_elixir, t_cost: 1, m_cost: 8
      """
    }

    {:ok, lib}
  end

  def build(other) do
    {:error, {:unknown_library, other}}
  end
end
