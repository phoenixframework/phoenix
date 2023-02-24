defmodule Mix.Tasks.Phx.Gen.Auth.Injector do
  @moduledoc false

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen.Auth.HashingLibrary

  @type schema :: %Schema{}
  @type context :: %Context{schema: schema}

  @doc """
  Injects a dependency into the contents of mix.exs
  """
  @spec mix_dependency_inject(String.t(), String.t()) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def mix_dependency_inject(mixfile, dependency) do
    with :ok <- ensure_not_already_injected(mixfile, dependency),
         {:ok, new_mixfile} <- do_mix_dependency_inject(mixfile, dependency) do
      {:ok, new_mixfile}
    end
  end

  @spec do_mix_dependency_inject(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :unable_to_inject}
  defp do_mix_dependency_inject(mixfile, dependency) do
    string_to_split_on = """
      defp deps do
        [
    """

    case split_with_self(mixfile, string_to_split_on) do
      {beginning, splitter, rest} ->
        new_mixfile =
          IO.iodata_to_binary([beginning, splitter, "      ", dependency, ?,, ?\n, rest])

        {:ok, new_mixfile}

      _ ->
        {:error, :unable_to_inject}
    end
  end

  @doc """
  Injects configuration for test environment into `file`.
  """
  @spec test_config_inject(String.t(), HashingLibrary.t()) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def test_config_inject(file, %HashingLibrary{} = hashing_library) when is_binary(file) do
    code_to_inject =
      hashing_library
      |> test_config_code()
      |> normalize_line_endings_to_file(file)

    inject_unless_contains(
      file,
      code_to_inject,
      # Matches the entire line and captures the line ending. In the
      # replace string:
      #
      # * the entire matching line is inserted with \\0,
      # * the actual code is injected with &2,
      # * and the appropriate newlines are injected using \\2.
      &Regex.replace(~r/(use Mix\.Config|import Config)(\r\n|\n|$)/, &1, "\\0\\2#{&2}\\2",
        global: false
      )
    )
  end

  @doc """
  Instructions to provide the user when `test_config_inject/2` fails.
  """
  @spec test_config_help_text(String.t(), HashingLibrary.t()) :: String.t()
  def test_config_help_text(file_path, %HashingLibrary{} = hashing_library) do
    """
    Add the following to #{Path.relative_to_cwd(file_path)}:

    #{hashing_library |> test_config_code() |> indent_spaces(4)}
    """
  end

  defp test_config_code(%HashingLibrary{test_config: test_config}) do
    String.trim("""
    # Only in tests, remove the complexity from the password hashing algorithm
    #{test_config}
    """)
  end

  @router_plug_anchor_line "plug :put_secure_browser_headers"

  @doc """
  Injects the fetch_current_<schema> plug into router's browser pipeline
  """
  @spec router_plug_inject(String.t(), context) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def router_plug_inject(file, %Context{schema: schema}) when is_binary(file) do
    inject_unless_contains(
      file,
      router_plug_code(schema),
      # Matches the entire line containing `anchor_line` and captures
      # the whitespace before the anchor. In the replace string
      #
      # * the entire matching line is inserted with \\0,
      # * the captured indent is inserted using \\1,
      # * the actual code is injected with &2,
      # * and the appropriate newline is injected using \\2
      &Regex.replace(~r/^(\s*)#{@router_plug_anchor_line}.*(\r\n|\n|$)/Um, &1, "\\0\\1#{&2}\\2",
        global: false
      )
    )
  end

  @doc """
  Instructions to provide the user when `inject_router_plug/2` fails.
  """
  @spec router_plug_help_text(String.t(), context) :: String.t()
  def router_plug_help_text(file_path, %Context{schema: schema}) do
    """
    Add the #{router_plug_name(schema)} plug to the :browser pipeline in #{Path.relative_to_cwd(file_path)}:

        pipeline :browser do
          ...
          #{@router_plug_anchor_line}
          #{router_plug_code(schema)}
        end
    """
  end

  defp router_plug_code(%Schema{} = schema) do
    "plug " <> router_plug_name(schema)
  end

  defp router_plug_name(%Schema{} = schema) do
    ":fetch_current_#{schema.singular}"
  end

  @doc """
  Injects a menu in the application layout
  """
  def app_layout_menu_inject(%Schema{} = schema, template_str) do
    with {:error, :unable_to_inject} <-
           app_layout_menu_inject_at_end_of_nav_tag(template_str, schema),
         {:error, :unable_to_inject} <-
           app_layout_menu_inject_after_opening_body_tag(template_str, schema) do
      {:error, :unable_to_inject}
    end
  end

  @doc """
  Instructions to provide the user when `app_layout_menu_inject/2` fails.
  """
  def app_layout_menu_help_text(file_path, %Schema{} = schema) do
    {_dup_check, code} = app_layout_menu_code_to_inject(schema)

    """
    Add the following #{schema.singular} menu items to your #{Path.relative_to_cwd(file_path)} layout file:

    #{code}
    """
  end

  @doc """
  Menu code to inject into the application layout template.
  """
  def app_layout_menu_code_to_inject(%Schema{} = schema, padding \\ 4, newline \\ "\n") do
    already_injected_str = "#{schema.route_prefix}/log_in"

    base_tailwind_classes = "text-[0.8125rem] leading-6 text-zinc-900"
    link_tailwind_classes = "#{base_tailwind_classes} font-semibold hover:text-zinc-700"

    template = """
    <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
      <%= if @current_#{schema.singular} do %>
        <li class="#{base_tailwind_classes}">
          <%= @current_#{schema.singular}.email %>
        </li>
        <li>
          <.link
            href={~p"#{schema.route_prefix}/settings"}
            class="#{link_tailwind_classes}"
          >
            Settings
          </.link>
        </li>
        <li>
          <.link
            href={~p"#{schema.route_prefix}/log_out"}
            method="delete"
            class="#{link_tailwind_classes}"
          >
            Log out
          </.link>
        </li>
      <% else %>
        <li>
          <.link
            href={~p"#{schema.route_prefix}/register"}
            class="#{link_tailwind_classes}"
          >
            Register
          </.link>
        </li>
        <li>
          <.link
            href={~p"#{schema.route_prefix}/log_in"}
            class="#{link_tailwind_classes}"
          >
            Log in
          </.link>
        </li>
      <% end %>
    </ul>\
    """

    {already_injected_str, indent_spaces(template, padding, newline)}
  end

  defp formatting_info(template, tag) do
    {padding, newline} =
      case Regex.run(~r/<?(([\r\n]{1})\s*)#{tag}/m, template, global: false) do
        [_, pre, "\n"] -> {String.trim_leading(pre, "\n") <> "  ", "\n"}
        [_, "\r\n" <> pre, "\r"] -> {String.trim_leading(pre, "\r\n") <> "  ", "\r\n"}
        _ -> {"", "\n"}
      end

    {String.length(padding), newline}
  end

  defp app_layout_menu_inject_at_end_of_nav_tag(file, schema) do
    {padding, newline} = formatting_info(file, "<\/nav>")
    {dup_check, code} = app_layout_menu_code_to_inject(schema, padding, newline)

    inject_unless_contains(
      file,
      dup_check,
      code,
      &Regex.replace(~r/(\s*)<\/nav>/m, &1, "#{newline}#{&2}\\0", global: false)
    )
  end

  defp app_layout_menu_inject_after_opening_body_tag(file, schema) do
    anchor_line = "<body"
    {padding, newline} = formatting_info(file, anchor_line)
    {dup_check, code} = app_layout_menu_code_to_inject(schema, padding, newline)

    inject_unless_contains(
      file,
      dup_check,
      code,
      # Matches the entire line containing `anchor_line` and captures
      # the whitespace before the anchor. In the replace string, the
      # entire matching line is inserted with \\0, then a newline then
      # the indent that was captured using \\1. &2 is the code to
      # inject.
      &Regex.replace(~r/^(\s*)#{anchor_line}.*(\r\n|\n|$)/Um, &1, "\\0#{&2}\\2", global: false)
    )
  end

  @doc """
  Injects code unless the existing code already contains `code_to_inject`
  """
  def inject_unless_contains(code, dup_check, inject_fn) do
    inject_unless_contains(code, dup_check, dup_check, inject_fn)
  end

  def inject_unless_contains(code, dup_check, code_to_inject, inject_fn)
      when is_binary(code) and is_binary(code_to_inject) and is_binary(dup_check) and
             is_function(inject_fn, 2) do
    with :ok <- ensure_not_already_injected(code, dup_check) do
      new_code = inject_fn.(code, code_to_inject)

      if code != new_code do
        {:ok, new_code}
      else
        {:error, :unable_to_inject}
      end
    end
  end

  @doc """
  Injects snippet before the final end in a file
  """
  @spec inject_before_final_end(String.t(), String.t()) :: {:ok, String.t()} | :already_injected
  def inject_before_final_end(code, code_to_inject)
      when is_binary(code) and is_binary(code_to_inject) do
    if String.contains?(code, code_to_inject) do
      :already_injected
    else
      new_code =
        code
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(code_to_inject)
        |> Kernel.<>("end\n")

      {:ok, new_code}
    end
  end

  @spec ensure_not_already_injected(String.t(), String.t()) :: :ok | :already_injected
  defp ensure_not_already_injected(file, inject) do
    if String.contains?(file, inject) do
      :already_injected
    else
      :ok
    end
  end

  @spec split_with_self(String.t(), String.t()) :: {String.t(), String.t(), String.t()} | :error
  defp split_with_self(contents, text) do
    case :binary.split(contents, text) do
      [left, right] -> {left, text, right}
      [_] -> :error
    end
  end

  @spec normalize_line_endings_to_file(String.t(), String.t()) :: String.t()
  defp normalize_line_endings_to_file(code, file) do
    String.replace(code, "\n", get_line_ending(file))
  end

  @spec get_line_ending(String.t()) :: String.t()
  defp get_line_ending(file) do
    case Regex.run(~r/\r\n|\n|$/, file) do
      [line_ending] -> line_ending
      [] -> "\n"
    end
  end

  defp indent_spaces(string, number_of_spaces, newline \\ "\n")
       when is_binary(string) and is_integer(number_of_spaces) do
    indent = String.duplicate(" ", number_of_spaces)

    string
    |> String.split("\n")
    |> Enum.map_join(newline, &(indent <> &1))
  end
end
