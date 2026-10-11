defmodule Phoenix.Integration.SummaryFormatter do
  @moduledoc false
  #
  # Custom ExUnit formatter that outputs structured JSON test metrics.
  #
  # By collecting test events in this custom formatter, we retain full
  # concurrency across test modules while gathering granular execution data.
  #
  # On suite finish, it writes a JSON summary file to
  # `PHX_INTEGRATION_SUMMARY_JSON` (required).
  #
  use GenServer

  def init(_opts) do
    json_path =
      case System.get_env("PHX_INTEGRATION_SUMMARY_JSON") do
        path when is_binary(path) and path != "" ->
          path

        _ ->
          IO.puts(
            :stderr,
            "Phoenix.Integration.SummaryFormatter requires the PHX_INTEGRATION_SUMMARY_JSON environment variable to be set."
          )

          System.halt(1)
      end

    case File.mkdir_p(Path.dirname(json_path)) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.puts(
          :stderr,
          "Phoenix.Integration.SummaryFormatter could not create parent directory for #{json_path}: #{:file.format_error(reason)}"
        )

        System.halt(1)
    end

    config =
      [
        job: System.get_env("PHX_TEST_JOB"),
        elixir: System.get_env("PHX_ELIXIR_VERSION", System.version()),
        otp: System.get_env("PHX_OTP_VERSION", System.otp_release())
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    state = %{
      json_path: json_path,
      config: config,
      suite_start: nil,
      timestamp: nil,
      modules: %{}
    }

    {:ok, state}
  end

  def handle_cast({:suite_started, _opts}, state) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    {:noreply, %{state | suite_start: monotonic_now(), timestamp: timestamp}}
  end

  def handle_cast({:suite_finished, times_us}, state) do
    write_json_summary(times_us, state)
    {:noreply, state}
  end

  def handle_cast({:module_started, %ExUnit.TestModule{name: name}}, state) do
    state = put_in(state.modules[name], %{start_ms: elapsed_ms(state)})
    {:noreply, state}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{name: name} = mod}, state) do
    # When module teardown fails, invalidate successful tests (matching ExUnit.CLIFormatter)
    tests =
      if match?({:failed, _}, mod.state) do
        Enum.map(mod.tests, fn
          %{state: nil} = test -> %{test | state: {:failed, "module teardown"}}
          test -> test
        end)
      else
        mod.tests
      end

    info = %{finish_ms: elapsed_ms(state), state: mod.state, tests: tests}
    state = update_in(state.modules[name], &Map.merge(&1, info))
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp write_json_summary(
         times_us,
         %{
           json_path: json_path,
           config: config,
           timestamp: timestamp,
           modules: modules
         }
       ) do
    modules = Enum.filter(modules, fn {_mod, %{tests: tests}} -> tests != [] end)
    tests = Enum.flat_map(modules, fn {_mod, %{tests: tests}} -> tests end)

    suite_result = [
      total: length(tests),
      passed: Enum.count(tests, &is_nil(&1.state)),
      failed: Enum.count(tests, &match?({:failed, _}, &1.state)),
      invalid: Enum.count(tests, &match?({:invalid, _}, &1.state))
    ]

    modules_stats =
      modules
      |> Enum.map(fn {mod, %{start_ms: start_ms, finish_ms: finish_ms, tests: mod_tests}} ->
        mod_failed = Enum.count(mod_tests, &match?({:failed, _}, &1.state))
        mod_invalid = Enum.count(mod_tests, &match?({:invalid, _}, &1.state))

        mod_status =
          cond do
            mod_invalid > 0 -> "invalid"
            mod_failed > 0 -> "failed"
            true -> "passed"
          end

        [
          module: mod |> Module.split() |> List.last(),
          full_module: inspect(mod),
          status: mod_status,
          failed: mod_failed,
          invalid: mod_invalid,
          test_count: length(mod_tests),
          duration_ms: finish_ms - start_ms,
          max_ms: us_to_ms(Enum.max(Enum.map(mod_tests, & &1.time))),
          start_ms: start_ms,
          finish_ms: finish_ms
        ]
      end)
      |> Enum.sort_by(& &1[:duration_ms], :desc)

    tests_stats =
      tests
      |> Enum.map(fn %ExUnit.Test{
                       name: name,
                       module: mod,
                       time: time,
                       tags: tags,
                       state: state
                     } ->
        status =
          case state do
            nil -> "passed"
            {status, _} -> Atom.to_string(status)
          end

        [
          name: name |> to_string() |> String.replace_prefix("test ", ""),
          module: mod |> Module.split() |> List.last(),
          status: status,
          duration_ms: us_to_ms(time),
          location: "#{Path.relative_to_cwd(tags.file)}:#{tags.line}"
        ]
      end)
      |> Enum.sort_by(& &1[:duration_ms], :desc)

    payload = [
      timestamp: timestamp,
      config: config,
      suite_result: suite_result,
      wall_time_ms: us_to_ms(times_us.run),
      modules: modules_stats,
      tests: tests_stats
    ]

    case File.write(json_path, format_json(payload)) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn(
          "Phoenix.Integration.SummaryFormatter failed to write summary to #{json_path}: #{:file.format_error(reason)}"
        )
    end
  end

  defp monotonic_now, do: System.monotonic_time(:millisecond)

  # Milliseconds since suite start. Monotonic readings have no meaning on their
  # own, so we only keep offsets; `timestamp` anchors them to wall-clock time.
  defp elapsed_ms(%{suite_start: suite_start}), do: monotonic_now() - suite_start

  defp us_to_ms(us), do: System.convert_time_unit(us, :microsecond, :millisecond)

  defp format_json(payload) do
    :json.format(
      payload,
      fn
        nil, _encode, state ->
          :json.format_value(:null, fn _, _ -> nil end, state)

        [{k, _} | _] = kvs, encode, state when is_atom(k) or is_binary(k) ->
          :json.format_key_value_list(kvs, encode, state)

        other, encode, state ->
          :json.format_value(other, encode, state)
      end,
      %{indent: 2}
    )
  end
end
