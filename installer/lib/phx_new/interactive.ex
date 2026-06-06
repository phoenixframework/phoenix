defmodule Phx.New.Interactive do
  @moduledoc false

  @databases [
    {"postgres", "PostgreSQL (postgrex)"},
    {"mysql", "MySQL (myxql)"},
    {"mssql", "MSSQL (tds)"},
    {"sqlite3", "SQLite3 (ecto_sqlite3)"},
    {"none", "None"}
  ]

  @web_options [
    {"live", "LiveView"},
    {"html", "HTML"},
    {"api", "API-only"}
  ]

  @asset_options [
    {"esbuild", "Esbuild + Tailwind"},
    {"volt", "Volt"},
    {"none", "None"}
  ]

  def run do
    catch_abort(fn ->
      info([:green, "\nInitialize your Phoenix project (press Ctrl+C to abort)\n", :reset])

      path = prompt_path()
      database = prompt_database()

      binary_id =
        if is_nil(database) do
          false
        else
          yes?("Use binary_id as primary key type?", false)
        end

      %{html: html, live: live, assets: assets, volt: volt} = prompt_web()
      dashboard = yes?("Include LiveDashboard (monitoring)?")
      mailer = yes?("Include Swoosh (mailer)?")
      gettext = yes?("Include Gettext (i18n)?")

      opts =
        [
          ecto: not is_nil(database),
          binary_id: binary_id,
          html: html,
          live: live,
          dashboard: dashboard,
          mailer: mailer,
          gettext: gettext,
          assets: assets,
          volt: volt
        ]
        |> maybe_put_database(database)

      print_summary(path, opts)
      print_equivalent_command(path, opts)

      if yes?("Continue with these settings?") do
        {:ok, path, opts}
      else
        abort()
      end
    end)
  end

  defp prompt_path do
    case prompt("Project path (e.g., hello_world):") do
      "" ->
        info([:red, "Project path cannot be empty. Please try again.\n", :reset])
        prompt_path()

      input ->
        input
    end
  end

  defp prompt_database do
    case prompt_choice("What is your database?", @databases, "postgres") do
      "none" -> nil
      database -> database
    end
  end

  defp prompt_web do
    case prompt_choice("Web interface?", @web_options, "live") do
      "api" -> %{html: false, live: false, assets: false, volt: false}
      "html" -> Map.merge(%{html: true, live: false}, prompt_assets())
      "live" -> Map.merge(%{html: true, live: true}, prompt_assets())
    end
  end

  defp prompt_assets do
    case prompt_choice("Assets?", @asset_options, "esbuild") do
      "esbuild" -> %{assets: true, volt: false}
      "volt" -> %{assets: true, volt: true}
      "none" -> %{assets: false, volt: false}
    end
  end

  defp prompt_choice(question, choices, default) do
    info("\n#{question}\n")

    count = length(choices)

    choices
    |> Enum.with_index(1)
    |> Enum.each(fn {{value, label}, index} ->
      default_marker = if value == default, do: " (default)", else: ""
      info("  #{index}) #{label}#{default_marker}")
    end)

    input = prompt("\nChoose [1-#{count}]:")

    case input do
      "" ->
        default

      _ ->
        case Integer.parse(input) do
          {index, ""} when index >= 1 and index <= count ->
            {value, _label} = Enum.at(choices, index - 1)
            value

          {_index, ""} ->
            info([:red, "Invalid choice. Please try again.\n", :reset])
            prompt_choice(question, choices, default)

          _ ->
            info([:red, "Invalid input. Please enter a number.\n", :reset])
            prompt_choice(question, choices, default)
        end
    end
  end

  defp print_summary(path, opts) do
    info("\nProject Summary\n")

    info("  Path:      #{path}")
    info("  Database:  #{database_summary(opts)}")
    info("  Web:       #{web_summary(opts)}")

    includes =
      for {key, label} <- [dashboard: "LiveDashboard", mailer: "mailer", gettext: "gettext"],
          opts[key],
          do: label

    if Enum.any?(includes) do
      info("  Includes:  #{Enum.join(includes, ", ")}")
    end

    info("")
  end

  defp database_summary(opts) do
    db = opts[:database] || "none"
    if opts[:binary_id], do: "#{db} (binary_id)", else: db
  end

  defp web_summary(opts) do
    case {opts[:html], opts[:live], opts[:assets], opts[:volt]} do
      {true, true, true, true} -> "LiveView (Volt)"
      {true, true, true, _} -> "LiveView"
      {true, true, false, _} -> "LiveView (no Esbuild, no Tailwind)"
      {true, false, true, true} -> "HTML (Volt)"
      {true, false, true, _} -> "HTML"
      {true, false, false, _} -> "HTML (no Esbuild, no Tailwind)"
      {false, _, _, _} -> "API-only"
    end
  end

  defp print_equivalent_command(path, opts) do
    flags =
      for {condition, flag} <- [
            {!opts[:ecto], "--no-ecto"},
            {opts[:ecto] && opts[:database] != "postgres", "--database #{opts[:database]}"},
            {opts[:binary_id], "--binary-id"},
            {!opts[:html], "--no-html"},
            {opts[:html] && !opts[:live], "--no-live"},
            {!opts[:dashboard], "--no-dashboard"},
            {!opts[:mailer], "--no-mailer"},
            {!opts[:gettext], "--no-gettext"},
            {!opts[:assets], "--no-assets"},
            {opts[:volt], "--volt"}
          ],
          condition,
          do: flag

    cmd = Enum.join(["mix phx.new #{path}" | flags], " ")

    info([:green, "Equivalent command:\n", :reset])
    info("  $ #{cmd}\n")
  end

  defp maybe_put_database(opts, nil), do: opts
  defp maybe_put_database(opts, database), do: Keyword.put(opts, :database, database)

  defp catch_abort(fun) do
    try do
      fun.()
    catch
      :throw, :abort ->
        info("\nAborted.\n")
        :abort
    end
  end

  defp abort, do: throw(:abort)

  defp info(msg), do: Mix.shell().info(msg)

  defp yes?(msg, default \\ true) do
    hint = if default, do: "[Yn]", else: "[yN]"

    case prompt("#{msg} #{hint}") |> String.downcase() do
      "" -> default
      "y" -> true
      "yes" -> true
      "n" -> false
      "no" -> false
      _ ->
        info([:red, "Please answer yes or no.\n", :reset])
        yes?(msg, default)
    end
  end

  defp prompt(msg) do
    case Mix.shell().prompt(msg) do
      :eof ->
        abort()

      result when is_binary(result) ->
        result
        |> String.trim()
    end
  end
end
