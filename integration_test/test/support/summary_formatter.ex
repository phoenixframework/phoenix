defmodule Phoenix.Integration.SummaryFormatter do
  @moduledoc false
  #
  # Custom ExUnit formatter that generates a markdown summary for GitHub Actions.
  #
  # When the `GITHUB_STEP_SUMMARY` environment variable is set (which GitHub Actions
  # automatically populates with a path to a step summary file), this formatter appends
  # a markdown summary containing overall test metrics, a concurrent module execution
  # timeline grouped into virtual worker lanes, a per-module duration breakdown, and a table
  # of test durations sorted from slowest to fastest.
  #
  # This formatter takes inspiration from `mix test --slowest` and `--slowest-modules`.
  # We do not use those built-in flags directly because they implicitly enable `--trace`,
  # which forces all tests to run synchronously/sequentially and significantly slows down
  # the integration test suite. By collecting test events in this custom formatter, we
  # retain full concurrency across test modules while still getting granular timing insights.
  #
  use GenServer

  def init(_opts) do
    {:ok, %{tests: [], modules: %{}, suite_start: nil}}
  end

  def handle_cast({:suite_started, _opts}, state) do
    {:noreply, %{state | suite_start: System.monotonic_time(:millisecond)}}
  end

  def handle_cast({event, %{name: name}}, state) when event in [:module_started, :case_started] do
    now = System.monotonic_time(:millisecond)
    suite_start = state.suite_start || now

    modules =
      Map.update(
        state.modules,
        name,
        %{start: now, finish: now},
        &Map.put(&1, :start, now)
      )

    {:noreply, %{state | modules: modules, suite_start: suite_start}}
  end

  def handle_cast({event, %{name: name}}, state)
      when event in [:module_finished, :case_finished] do
    now = System.monotonic_time(:millisecond)

    modules =
      Map.update(
        state.modules,
        name,
        %{start: now, finish: now},
        &Map.put(&1, :finish, now)
      )

    {:noreply, %{state | modules: modules}}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    {:noreply, %{state | tests: [test | state.tests]}}
  end

  def handle_cast({:suite_finished, run_data}, %{tests: tests} = state) do
    summary_file = System.get_env("GITHUB_STEP_SUMMARY")

    if is_binary(summary_file) and summary_file != "" do
      executed =
        Enum.reject(tests, fn test ->
          match?({:excluded, _}, test.state) or match?({:skipped, _}, test.state)
        end)

      slowest = Enum.sort_by(executed, &(&1.time || 0), :desc)
      write_github_summary(summary_file, run_data, state, slowest)
    end

    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp write_github_summary(
         summary_file,
         run_data,
         %{tests: tests, modules: modules, suite_start: suite_start},
         slowest
       ) do
    total = length(tests)
    failed = Enum.count(tests, &match?({:failed, _}, &1.state))
    invalid = Enum.count(tests, &match?({:invalid, _}, &1.state))
    skipped = Enum.count(tests, &match?({:skipped, _}, &1.state))
    excluded = Enum.count(tests, &match?({:excluded, _}, &1.state))
    passed = Enum.count(tests, &is_nil(&1.state))

    total_failures = failed + invalid
    status = if total_failures == 0, do: "Passed", else: "Failed (#{total_failures})"

    wall_time_ms =
      case run_data do
        %{run: run} when is_integer(run) -> div(run, 1000)
        _ -> 0
      end

    total_executed_time_us = Enum.sum(Enum.map(slowest, &(&1.time || 0)))

    modules_stats =
      tests
      |> Enum.group_by(& &1.module)
      |> Enum.map(fn {mod, mod_tests} ->
        mod_executed =
          Enum.reject(mod_tests, fn test ->
            match?({:excluded, _}, test.state) or match?({:skipped, _}, test.state)
          end)

        total_us = Enum.sum(Enum.map(mod_executed, &(&1.time || 0)))
        max_us = Enum.max(Enum.map(mod_executed, &(&1.time || 0)), fn -> 0 end)
        avg_us = if mod_executed != [], do: div(total_us, length(mod_executed)), else: 0

        mod_failed = Enum.count(mod_tests, &match?({:failed, _}, &1.state))
        mod_invalid = Enum.count(mod_tests, &match?({:invalid, _}, &1.state))
        mod_failures = mod_failed + mod_invalid
        mod_status = if mod_failures == 0, do: "passed", else: "failed (#{mod_failures})"

        %{
          module: mod,
          status: mod_status,
          test_count: length(mod_tests),
          total_us: total_us,
          avg_us: avg_us,
          max_us: max_us
        }
      end)
      |> Enum.sort_by(& &1.total_us, :desc)

    partition_info =
      case System.get_env("MIX_TEST_PARTITION") do
        nil -> ""
        "" -> ""
        partition -> " / partition #{partition}"
      end

    env_info = "Elixir #{System.version()} / OTP #{System.otp_release()}#{partition_info}"

    sections = [
      """
      ## Phoenix Integration Tests (#{env_info}): #{status}

      | Total | Passed | Failed | Excluded | Skipped | Total Wall Time |
      | :---: | :---: | :---: | :---: | :---: | :---: |
      | **#{total}** | **#{passed}** | **#{total_failures}** | **#{excluded}** | **#{skipped}** | **#{format_duration(wall_time_ms)}** |
      """,
      format_mermaid_gantt(modules, suite_start),
      """
      <details open>
      <summary><b>Module Breakdown</b></summary>

      | Module | Status | Tests | Total Duration | % of Total | Avg / Test | Max / Test |
      | :--- | :---: | :---: | :--- | :---: | :--- | :--- |
      #{Enum.map_join(modules_stats, "\n", &format_module_markdown_row(&1, total_executed_time_us))}

      </details>
      """,
      """
      <details open>
      <summary><b>Test Durations (Slowest to Fastest)</b></summary>

      | Status | Duration | Test | Module | Location |
      | :--- | :--- | :--- | :--- | :--- |
      #{Enum.map_join(slowest, "\n", &format_markdown_row/1)}

      </details>
      """
    ]

    markdown =
      sections
      |> Enum.reject(&(&1 in ["", nil]))
      |> Enum.map_join("\n\n", &String.trim/1)
      |> Kernel.<>("\n\n")

    case File.write(summary_file, markdown, [:append]) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Failed to write integration test summary to #{summary_file}: #{inspect(reason)}")
    end
  end

  defp format_mermaid_gantt(modules, suite_start) when map_size(modules) > 0 do
    suite_start =
      suite_start ||
        modules
        |> Map.values()
        |> Enum.map(& &1.start)
        |> Enum.min(fn -> 0 end)

    sorted_modules =
      modules
      |> Enum.sort_by(fn {mod, %{start: s, finish: f}} -> {s, f || s, mod} end)

    lanes =
      Enum.reduce(sorted_modules, [], fn item, acc_lanes ->
        assign_to_lane(acc_lanes, item, [])
      end)
      |> Enum.map(&Enum.reverse/1)

    {slowest_mod, _} =
      Enum.max_by(
        modules,
        fn {_mod, %{start: s, finish: f}} -> (f || s) - s end,
        fn -> {nil, nil} end
      )

    section_rows =
      lanes
      |> Enum.with_index(1)
      |> Enum.map(fn {lane, idx} ->
        tasks =
          Enum.map(lane, fn {mod, %{start: s, finish: f}} ->
            module_name = format_gantt_module_name(mod)
            duration_ms = max(1000, (f || s) - s)
            start_ms = max(0, s - suite_start)
            finish_ms = start_ms + duration_ms

            start_str = format_gantt_time(start_ms)
            finish_str = format_gantt_time(finish_ms)
            tag = if mod == slowest_mod, do: ":crit, active,", else: ":active,"

            "    #{module_name} #{tag} #{start_str}, #{finish_str}"
          end)

        "    section Lane #{idx}\n" <> Enum.join(tasks, "\n")
      end)

    """
    <details open>
    <summary><b>Module Execution Timeline</b></summary>

    ```mermaid
    ---
    displayMode: compact
    ---
    gantt
        title Module Execution Timeline
        dateFormat mm:ss
        axisFormat %M:%S
        todayMarker off
    #{Enum.join(section_rows, "\n")}
    ```

    </details>
    """
  end

  defp format_mermaid_gantt(_modules, _suite_start), do: ""

  defp assign_to_lane([], item, acc) do
    Enum.reverse([[item] | acc])
  end

  defp assign_to_lane(
         [[{_last_mod, %{finish: last_finish, start: last_start}} | _] = lane | rest],
         {_mod, %{start: s}} = item,
         acc
       ) do
    if (last_finish || last_start) <= s do
      Enum.reverse(acc) ++ [[item | lane] | rest]
    else
      assign_to_lane(rest, item, [lane | acc])
    end
  end

  defp format_gantt_module_name(nil), do: "Unknown"

  defp format_gantt_module_name(mod) do
    mod
    |> Module.split()
    |> List.last()
    |> String.replace_prefix("UmbrellaAppWith", "Umbrella")
    |> String.replace_prefix("AppWith", "")
    |> String.replace("Adapter", "")
    |> String.replace_suffix("Test", "")
  end

  defp format_gantt_time(ms) do
    total_seconds = div(ms, 1000)
    mins = div(total_seconds, 60)
    secs = rem(total_seconds, 60)

    "#{String.pad_leading(Integer.to_string(mins), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_module_markdown_row(
         %{
           module: mod,
           status: status,
           test_count: count,
           total_us: total_us,
           avg_us: avg_us,
           max_us: max_us
         },
         total_suite_us
       ) do
    module_name = if mod, do: mod |> Module.split() |> List.last(), else: "Unknown"
    total_ms = div(total_us, 1000)
    avg_ms = div(avg_us, 1000)
    max_ms = div(max_us, 1000)

    pct =
      if total_suite_us > 0 do
        Float.round(total_us / total_suite_us * 100, 1)
      else
        0.0
      end

    "| `#{module_name}` | #{status} | #{count} | `#{format_duration(total_ms)}` | #{pct}% | `#{format_duration(avg_ms)}` | `#{format_duration(max_ms)}` |"
  end

  defp format_markdown_row(%ExUnit.Test{
         name: name,
         module: mod,
         time: time,
         tags: tags,
         state: state
       }) do
    ms = div(time || 0, 1000)
    test_name = name |> to_string() |> String.replace_prefix("test ", "")
    module_name = if mod, do: mod |> Module.split() |> List.last(), else: "Unknown"
    file = if f = tags[:file], do: Path.relative_to(f, File.cwd!()), else: "unknown"

    status = if is_nil(state), do: "passed", else: "failed"

    "| #{status} | `#{format_duration(ms)}` | #{escape_markdown(test_name)} | `#{module_name}` | `#{file}:#{tags[:line]}` |"
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    total_seconds = round(ms / 1000)
    mins = div(total_seconds, 60)
    secs = rem(total_seconds, 60)

    if mins == 0 do
      "#{secs}s"
    else
      "#{mins}m #{String.pad_leading(Integer.to_string(secs), 2, "0")}s"
    end
  end

  defp escape_markdown(text) do
    text
    |> Plug.HTML.html_escape()
    |> String.replace("|", "\\|")
    |> String.replace("\r\n", " ")
    |> String.replace("\n", " ")
  end
end
