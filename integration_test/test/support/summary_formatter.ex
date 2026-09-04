defmodule Phoenix.Integration.SummaryFormatter do
  @moduledoc false
  #
  # Custom ExUnit formatter that outputs structured JSON test metrics.
  #
  # By collecting test events in this custom formatter, we retain full concurrency
  # across test modules while gathering granular execution durations and concurrency
  # intervals.
  #
  # On suite finish, it writes a JSON summary file to `PHX_INTEGRATION_SUMMARY_JSON`
  # (defaulting to "tmp/integration_test_summary.json").
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
    json_path =
      System.get_env("PHX_INTEGRATION_SUMMARY_JSON") || "tmp/integration_test_summary.json"

    executed =
      Enum.reject(tests, fn test ->
        match?({:excluded, _}, test.state) or match?({:skipped, _}, test.state)
      end)

    slowest = Enum.sort_by(executed, &(&1.time || 0), :desc)
    executed_modules = MapSet.new(slowest, & &1.module)

    write_json_summary(json_path, run_data, state, slowest, executed_modules)

    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp write_json_summary(
         json_path,
         run_data,
         %{tests: tests, modules: modules, suite_start: suite_start},
         slowest,
         executed_modules
       ) do
    total = length(tests)
    failed = Enum.count(tests, &match?({:failed, _}, &1.state))
    invalid = Enum.count(tests, &match?({:invalid, _}, &1.state))
    skipped = Enum.count(tests, &match?({:skipped, _}, &1.state))
    excluded = Enum.count(tests, &match?({:excluded, _}, &1.state))
    passed = Enum.count(tests, &is_nil(&1.state))

    total_failures = failed + invalid
    status = if total_failures == 0, do: "passed", else: "failed"

    wall_time_ms =
      case run_data do
        %{run: run} when is_integer(run) -> div(run, 1000)
        _ -> 0
      end

    total_executed_time_us = Enum.sum(Enum.map(slowest, &(&1.time || 0)))

    modules_stats =
      tests
      |> Enum.group_by(& &1.module)
      |> Enum.filter(fn {mod, _tests} -> MapSet.member?(executed_modules, mod) end)
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
        mod_status = if mod_failures == 0, do: "passed", else: "failed"

        suite_start_ms = suite_start || 0
        mod_timing = Map.get(modules, mod, %{})
        start_ms = Map.get(mod_timing, :start, suite_start_ms)
        finish_ms = Map.get(mod_timing, :finish, start_ms)
        module_name = if mod, do: mod |> Module.split() |> List.last(), else: "Unknown"

        %{
          module: module_name,
          full_module: if(mod, do: inspect(mod), else: "Unknown"),
          status: mod_status,
          failures: mod_failures,
          test_count: length(mod_executed),
          total_us: total_us,
          avg_us: avg_us,
          max_us: max_us,
          start_ms: max(0, start_ms - suite_start_ms),
          finish_ms: max(0, finish_ms - suite_start_ms)
        }
      end)
      |> Enum.sort_by(& &1.total_us, :desc)

    slowest_tests =
      Enum.map(slowest, fn %ExUnit.Test{
                             name: name,
                             module: mod,
                             time: time,
                             tags: tags,
                             state: state
                           } ->
        test_name = name |> to_string() |> String.replace_prefix("test ", "")
        module_name = if mod, do: mod |> Module.split() |> List.last(), else: "Unknown"
        file = if f = tags[:file], do: Path.relative_to(f, File.cwd!()), else: "unknown"
        line = tags[:line] || 0
        status = if is_nil(state), do: "passed", else: "failed"

        %{
          name: test_name,
          module: module_name,
          duration_ms: div(time || 0, 1000),
          time_us: time || 0,
          file: file,
          line: line,
          status: status
        }
      end)

    service =
      System.get_env("PHX_TEST_SERVICE") || System.get_env("PHX_TEST_GROUP") || "none"

    payload = %{
      service: service,
      elixir: System.get_env("PHX_ELIXIR_VERSION") || System.version(),
      otp: System.get_env("PHX_OTP_VERSION") || System.otp_release(),
      status: status,
      total_failures: total_failures,
      total_tests: total,
      executed_tests: length(slowest),
      passed_tests: passed,
      failed_tests: total_failures,
      skipped_tests: skipped,
      excluded_tests: excluded,
      wall_time_ms: wall_time_ms,
      total_executed_time_us: total_executed_time_us,
      modules: modules_stats,
      slowest_tests: slowest_tests
    }

    json_str =
      cond do
        Code.ensure_loaded?(JSON) ->
          apply(JSON, :encode!, [payload])

        Code.ensure_loaded?(Jason) ->
          apply(Jason, :encode!, [payload])

        true ->
          raise "Neither JSON nor Jason available for encoding summary payload"
      end

    json_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(json_path, json_str)
  end
end
