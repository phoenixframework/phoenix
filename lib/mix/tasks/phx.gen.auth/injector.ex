defmodule Mix.Tasks.Phx.Gen.Auth.Injector do
  @moduledoc false

  alias Mix.Phoenix.Schema
  alias Mix.Tasks.Phx.Gen.Auth.HashingLibrary

  @type schema :: %Schema{}

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
  Injects configuration into `file`.
  """
  def config_inject(file, code_to_inject) when is_binary(file) and is_binary(code_to_inject) do
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
  Injects configuration for test environment into `file`.
  """
  @spec test_config_inject(String.t(), HashingLibrary.t()) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def test_config_inject(file, %HashingLibrary{} = hashing_library) when is_binary(file) do
    code_to_inject =
      hashing_library
      |> test_config_code()
      |> normalize_line_endings_to_file(file)

    config_inject(file, code_to_inject)
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
  Injects the fetch_current_scope_for_<schema> plug into router's browser pipeline
  """
  @spec router_plug_inject(String.t(), binding :: keyword()) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def router_plug_inject(file, binding) when is_binary(file) do
    inject_unless_contains(
      file,
      router_plug_code(binding),
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
  @spec router_plug_help_text(String.t(), binding :: keyword()) :: String.t()
  def router_plug_help_text(file_path, binding) do
    """
    Add the #{router_plug_name(binding)} plug to the :browser pipeline in #{Path.relative_to_cwd(file_path)}:

        pipeline :browser do
          ...
          #{@router_plug_anchor_line}
          #{router_plug_code(binding)}
        end
    """
  end

  defp router_plug_code(binding) do
    "plug " <> router_plug_name(binding)
  end

  defp router_plug_name(binding) do
    ":fetch_#{binding[:scope_config].scope.assign_key}_for_#{binding[:schema].singular}"
  end

  @doc """
  Injects a menu in the application layout
  """
  def app_layout_menu_inject(binding, template_str) do
    with {:error, :unable_to_inject} <-
           app_layout_menu_inject_at_end_of_nav_tag(binding, template_str),
         {:error, :unable_to_inject} <-
           app_layout_menu_inject_after_opening_body_tag(binding, template_str) do
      {:error, :unable_to_inject}
    end
  end

  @doc """
  Instructions to provide the user when `app_layout_menu_inject/2` fails.
  """
  def app_layout_menu_help_text(file_path, binding) do
    {_dup_check, code} = app_layout_menu_code_to_inject(binding)

    """
    Add the following #{binding[:schema].singular} menu items to your #{Path.relative_to_cwd(file_path)} layout file:

    #{code}
    """
  end

  @doc """
  Menu code to inject into the application layout template.
  """
  def app_layout_menu_code_to_inject(binding, padding \\ 4, newline \\ "\n") do
    schema = binding[:schema]
    scope_config = binding[:scope_config]
    already_injected_str = "#{schema.route_prefix}/log-in"

    template = """
    <ul class="menu menu-horizontal w-full relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
      <%= if @#{scope_config.scope.assign_key} do %>
        <li>
          {@#{scope_config.scope.assign_key}.#{schema.singular}.email}
        </li>
        <li>
          <.link href={~p"#{schema.route_prefix}/settings"}>Settings</.link>
        </li>
        <li>
          <.link href={~p"#{schema.route_prefix}/log-out"} method="delete">Log out</.link>
        </li>
      <% else %>
        <li>
          <.link href={~p"#{schema.route_prefix}/register"}>Register</.link>
        </li>
        <li>
          <.link href={~p"#{schema.route_prefix}/log-in"}>Log in</.link>
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

  defp app_layout_menu_inject_at_end_of_nav_tag(binding, file) do
    {padding, newline} = formatting_info(file, "<\/nav>")
    {dup_check, code} = app_layout_menu_code_to_inject(binding, padding, newline)

    inject_unless_contains(
      file,
      dup_check,
      code,
      &Regex.replace(~r/(\s*)<\/nav>/m, &1, "#{newline}#{&2}\\0", global: false)
    )
  end

  defp app_layout_menu_inject_after_opening_body_tag(binding, file) do
    anchor_line = "<body"
    {padding, newline} = formatting_info(file, anchor_line)
    {dup_check, code} = app_layout_menu_code_to_inject(binding, padding, newline)

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
