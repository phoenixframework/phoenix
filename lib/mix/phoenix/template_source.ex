defmodule Mix.Phoenix.TemplateSource do
  @moduledoc false

  @type template_path :: String.t()
  @type binding :: keyword

  @callback render_template(template_path, binding) :: {:ok, String.t()} | {:error, :not_found}

  defmacro __using__(options) do
    template_patterns = Keyword.fetch!(options, :template_patterns) |> List.wrap()
    exclude_patterns = Keyword.get(options, :exclude_patterns, []) |> List.wrap()

    quote do
      @phoenix_template_source_template_patterns unquote(template_patterns)
      @phoenix_template_source_exclude_patterns unquote(exclude_patterns)
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    template_patterns =
      Module.get_attribute(env.module, :phoenix_template_source_template_patterns)

    exclude_patterns = Module.get_attribute(env.module, :phoenix_template_source_exclude_patterns)

    generated_function_heads =
      for path <- template_paths(template_patterns, exclude_patterns) do
        compiled = EEx.compile_file(path)
        private_function_name = String.to_atom(path)

        quote do
          @external_resource unquote(path)
          @file unquote(path)
          defp unquote(private_function_name)(var!(assigns)) do
            _ = var!(assigns)
            unquote(compiled)
          end

          def render_template(unquote(path), assigns) do
            {:ok, unquote(private_function_name)(assigns)}
          end
        end
      end

    quote do
      unquote(generated_function_heads)
      def render_template(_template, assigns), do: {:error, :not_found}

      @doc false
      def __mix_recompile__? do
        unquote(hash(template_patterns, exclude_patterns)) !=
          unquote(__MODULE__).hash(
            @phoenix_template_source_template_patterns,
            @phoenix_template_source_exclude_patterns
          )
      end
    end
  end

  @doc false
  def hash(template_patterns, exclude_patterns) do
    template_paths(template_patterns, exclude_patterns)
    |> Enum.sort()
    |> :erlang.md5()
  end

  @doc false
  def template_paths(template_patterns, exclude_patterns) do
    MapSet.difference(
      MapSet.new(files_from_patterns(template_patterns)),
      MapSet.new(files_from_patterns(exclude_patterns))
    )
    |> MapSet.to_list()
  end

  defp files_from_patterns(patterns) do
    patterns
    |> Stream.flat_map(&Path.wildcard/1)
    |> Stream.uniq()
    |> Stream.filter(&File.regular?/1)
    |> Enum.to_list()
  end
end
