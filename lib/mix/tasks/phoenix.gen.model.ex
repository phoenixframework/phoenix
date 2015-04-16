defmodule Mix.Tasks.Phoenix.Gen.Model do
  use Mix.Task

  @shortdoc "Generates an Ecto model"

  @moduledoc """
  Generates an Ecto model in your Phoenix application.

      mix phoenix.gen.model User users name:string age:integer

  The first argument is the module name followed by its plural
  name (used for the schema).

  The generated model will contain:

    * a model in web/models
    * a migration file for the repository

  ## Attributes

  The resource fields are given using `name:type` syntax
  where type are the types supported by Ecto. Ommitting
  the type makes it default to `:string`:

      mix phoenix.gen.model User users name age:integer

  Furthermore an array type can also be given if it is
  supported by your database, although it requires the
  type of the underlying array element to be given too:

      mix phoenix.gen.model User users nicknames:array:string

  ## Namespaced resources

  Resources can be namespaced, for such, it is just necessary
  to namespace the first argument of the generator:

      mix phoenix.gen.model Admin.User users name:string age:integer

  """
  def run([singular, plural|attrs]) do
    if String.contains?(plural, ":"), do: raise_with_help

    attrs     = Mix.Phoenix.attrs(attrs)
    binding   = Mix.Phoenix.inflect(singular)
    path      = binding[:path]
    migration = String.replace(path, "/", "_")

    binding = binding ++
              [attrs: attrs, plural: plural, types: types(attrs),
               defaults: defaults(attrs), params: Mix.Phoenix.params(attrs)]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "migration.exs",  "priv/repo/migrations/#{timestamp()}_create_#{migration}.exs"},
      {:eex, "model.ex",       "web/models/#{path}.ex"},
      {:eex, "model_test.exs", "test/models/#{path}_test.exs"},
    ]
  end

  def run(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.model expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.model User users name:string
    """
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  defp types(attrs) do
    Enum.into attrs, %{}, fn
      {k, {c, v}} -> {k, {c, value_to_type(v)}}
      {k, v}      -> {k, value_to_type(v)}
    end
  end

  defp defaults(attrs) do
    Enum.into attrs, %{}, fn
      {k, :boolean}  -> {k, ", default: false"}
      {k, _}         -> {k, ""}
    end
  end

  defp value_to_type(:text), do: :string
  defp value_to_type(:uuid), do: Ecto.UUID
  defp value_to_type(:date), do: Ecto.Date
  defp value_to_type(:time), do: Ecto.Time
  defp value_to_type(:datetime), do: Ecto.DateTime
  defp value_to_type(v) do
    if Code.ensure_loaded?(Ecto.Type) and not Ecto.Type.primitive?(v) do
      Mix.raise "Unknown type `#{v}` given to generator"
    else
      v
    end
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/model")
  end
end
