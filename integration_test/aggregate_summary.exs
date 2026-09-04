# Script to aggregate integration test shard JSON summaries into a single GitHub Actions summary.
#
# Usage:
#   elixir integration_test/aggregate_summary.exs [directory_with_json_files]
#

defmodule Phoenix.Integration.AggregateSummary do
  @service_order ["postgresql", "mysql", "mssql", "none"]

  def run(argv) do
    summaries_dir = List.first(argv) || "tmp/summaries"

    json_files = Path.wildcard(Path.join(summaries_dir, "**/*.json"))

    if json_files == [] do
      IO.puts(:stderr, "No summary JSON files found in #{summaries_dir}")

      if summary_file = System.get_env("GITHUB_STEP_SUMMARY") do
        File.write!(
          summary_file,
          "## Phoenix Integration Tests: No summary artifacts found\n\n",
          [:append]
        )
      end

      System.halt(1)
    end

    summaries =
      Enum.map(json_files, fn file ->
        file
        |> File.read!()
        |> decode_json!()
      end)

    markdown = format_report(summaries)

    if summary_file = System.get_env("GITHUB_STEP_SUMMARY") do
      case File.write(summary_file, markdown, [:append]) do
        :ok ->
          :ok

        {:error, reason} ->
          IO.warn(
            "Failed to write integration test summary to #{summary_file}: #{inspect(reason)}"
          )
      end
    end

    IO.puts(markdown)

    any_failed? =
      Enum.any?(summaries, fn s ->
        s["status"] != "passed" or (s["total_failures"] || 0) > 0
      end)

    matrix_failed? = System.get_env("MATRIX_RESULT") in ["failure", "cancelled"]

    if any_failed? or matrix_failed? do
      System.halt(1)
    else
      System.halt(0)
    end
  end

  defp decode_json!(content) do
    cond do
      Code.ensure_loaded?(JSON) ->
        apply(JSON, :decode!, [content])

      Code.ensure_loaded?(Jason) ->
        apply(Jason, :decode!, [content])

      true ->
        raise "Neither JSON nor Jason available for decoding summary"
    end
  end

  def format_report(summaries) do
    versions =
      summaries
      |> Enum.map(fn s -> {s["elixir"], s["otp"]} end)
      |> Enum.uniq()
      |> Enum.sort_by(fn {elixir, _otp} -> elixir end)

    version_headers = format_version_headers(versions)

    peak_wall_time =
      summaries
      |> Enum.map(&(&1["wall_time_ms"] || 0))
      |> Enum.max(fn -> 0 end)

    total_shards = length(summaries)
    total_suites = length(versions)

    any_failed? =
      Enum.any?(summaries, fn s ->
        s["status"] != "passed" or (s["total_failures"] || 0) > 0
      end)

    overall_status = if any_failed?, do: "Failed", else: "Passed"

    summary_header = """
    ## Phoenix Integration Tests Summary

    | Total Suites | Total Shards | Overall Status | Peak Wall Time |
    | :---: | :---: | :---: | :---: |
    | **#{total_suites}** | **#{total_shards}** | **#{overall_status}** | **`#{format_duration(peak_wall_time)}`** |
    """

    overview_table = format_combined_overview_table(summaries, versions)
    slowest_table = format_combined_slowest_table(summaries, versions, version_headers)
    shard_details = format_combined_shard_details(summaries, versions, version_headers)

    [summary_header, overview_table, slowest_table, shard_details]
    |> Enum.reject(&(&1 in ["", nil]))
    |> Enum.join("\n\n")
    |> String.trim()
    |> Kernel.<>("\n\n")
  end

  defp format_combined_overview_table(summaries, versions) do
    grouped =
      summaries
      |> Enum.group_by(fn s -> {s["elixir"], s["otp"]} end)

    table_rows =
      Enum.map_join(versions, "\n", fn {elixir, otp} = ver ->
        shard_summaries = Map.get(grouped, ver, [])
        sorted_shards = sort_shards(shard_summaries)

        total_executed = Enum.sum(Enum.map(sorted_shards, &(&1["executed_tests"] || 0)))
        total_passed = Enum.sum(Enum.map(sorted_shards, &(&1["passed_tests"] || 0)))
        total_failed = Enum.sum(Enum.map(sorted_shards, &(&1["total_failures"] || 0)))
        max_wall_time = Enum.max(Enum.map(sorted_shards, &(&1["wall_time_ms"] || 0)), fn -> 0 end)

        status_str = if total_failed == 0, do: "Passed", else: "Failed (#{total_failed})"

        overall_slowest =
          sorted_shards
          |> Enum.flat_map(&(&1["slowest_tests"] || []))
          |> Enum.max_by(&(&1["time_us"] || 0), fn -> nil end)

        overall_slowest_desc = format_test_desc(overall_slowest)

        total_row =
          "| **Elixir #{elixir} / OTP #{otp}** | **All** | **#{status_str}** | **#{total_passed}/#{total_executed}** | **`#{format_duration(max_wall_time)}`** | #{overall_slowest_desc} |"

        shard_rows =
          Enum.map_join(sorted_shards, "\n", fn shard ->
            service_label = service_name(shard["service"])
            status = shard_status_cell(shard)
            executed = shard["executed_tests"] || 0
            wall_time = format_duration(shard["wall_time_ms"] || 0)
            slowest_desc = format_shard_slowest(shard["slowest_tests"])

            "| | #{service_label} | #{status} | #{executed} | `#{wall_time}` | #{slowest_desc} |"
          end)

        "#{total_row}\n#{shard_rows}"
      end)

    """
    | Elixir / OTP | Database | Status | Tests | Wall Time | Slowest Test |
    | :--- | :--- | :---: | :---: | :---: | :--- |
    #{table_rows}
    """
    |> String.trim()
  end

  defp format_combined_slowest_table(summaries, versions, version_headers) do
    all_tests =
      for s <- summaries,
          t <- s["slowest_tests"] || [] do
        Map.merge(t, %{
          "service" => s["service"],
          "elixir" => s["elixir"],
          "otp" => s["otp"]
        })
      end

    grouped_tests =
      all_tests
      |> Enum.group_by(fn t -> {t["module"], t["name"]} end)
      |> Enum.map(fn {{mod, name}, instances} ->
        first = hd(instances)

        durations_by_ver =
          Enum.into(instances, %{}, fn inst ->
            ms = inst["duration_ms"] || div(inst["time_us"] || 0, 1000)
            {{inst["elixir"], inst["otp"]}, ms}
          end)

        max_duration_ms =
          durations_by_ver
          |> Map.values()
          |> Enum.max(fn -> 0 end)

        statuses = Enum.map(instances, & &1["status"])
        all_passed? = Enum.all?(statuses, &(&1 == "passed"))
        status = if all_passed?, do: "passed", else: "failed"

        %{
          module: mod,
          name: name,
          service: first["service"],
          file: first["file"],
          line: first["line"],
          durations_by_ver: durations_by_ver,
          max_duration_ms: max_duration_ms,
          status: status
        }
      end)
      |> Enum.sort_by(& &1.max_duration_ms, :desc)
      |> Enum.take(10)

    if grouped_tests != [] do
      ver_header_cols = Enum.map_join(version_headers, " | ", fn {_, h} -> h end)
      ver_align_cols = Enum.map_join(version_headers, " | ", fn _ -> ":---" end)

      rows =
        Enum.map_join(grouped_tests, "\n", fn t ->
          ver_duration_cols =
            Enum.map_join(versions, " | ", fn ver ->
              case Map.get(t.durations_by_ver, ver) do
                nil -> "-"
                ms -> "`#{format_duration(ms)}`"
              end
            end)

          "| #{t.status} | `#{format_duration(t.max_duration_ms)}` | #{ver_duration_cols} | #{escape_markdown(t.name)} | `#{t.module}` | #{service_name(t.service)} | `#{t.file}:#{t.line}` |"
        end)

      """
      <details open>
      <summary><b>Top 10 Slowest Tests</b></summary>

      | Status | Max Duration | #{ver_header_cols} | Test | Module | Database | Location |
      | :---: | :--- | #{ver_align_cols} | :--- | :--- | :---: | :--- |
      #{rows}

      </details>
      """
      |> String.trim()
    else
      ""
    end
  end

  defp format_combined_shard_details(summaries, versions, version_headers) do
    shards_by_service = Enum.group_by(summaries, & &1["service"])

    services =
      @service_order
      |> Enum.filter(&Map.has_key?(shards_by_service, &1))
      |> Kernel.++(Enum.sort(Map.keys(shards_by_service) -- @service_order))

    Enum.map_join(services, "\n\n", fn service ->
      service_summaries =
        shards_by_service
        |> Map.get(service, [])
        |> Enum.sort_by(fn s -> {s["elixir"], s["otp"]} end)

      format_service_accordion(service, service_summaries, versions, version_headers)
    end)
  end

  defp format_service_accordion(service, service_summaries, versions, version_headers) do
    service_label = service_name(service)

    total_failures =
      Enum.sum(Enum.map(service_summaries, &(&1["total_failures"] || 0)))

    max_tests =
      Enum.max(Enum.map(service_summaries, &(&1["executed_tests"] || 0)), fn -> 0 end)

    details_tag = if total_failures > 0, do: "<details open>", else: "<details>"
    status_label = if total_failures == 0, do: "passed", else: "failed (#{total_failures})"

    wall_times_summary =
      Enum.map_join(service_summaries, " | ", fn s ->
        "#{format_duration(s["wall_time_ms"] || 0)} in #{short_version(s["elixir"])}"
      end)

    modules_section = format_service_modules_table(service_summaries, versions, version_headers)
    timelines_section = format_service_timelines(service_summaries)
    tests_section = format_service_tests_table(service_summaries, versions, version_headers)

    """
    #{details_tag}
    <summary><b>#{service_label} Details</b>: #{status_label} — #{max_tests} tests (#{wall_times_summary})</summary>

    #{timelines_section}

    #{modules_section}

    #{tests_section}
    </details>
    """
    |> String.trim()
  end

  defp format_service_modules_table(service_summaries, versions, version_headers) do
    all_modules =
      for s <- service_summaries,
          m <- s["modules"] || [] do
        Map.merge(m, %{"elixir" => s["elixir"], "otp" => s["otp"]})
      end

    grouped_modules =
      all_modules
      |> Enum.group_by(& &1["module"])
      |> Enum.map(fn {mod, instances} ->
        test_count = Enum.max(Enum.map(instances, &(&1["test_count"] || 0)), fn -> 0 end)

        durations_by_ver =
          Enum.into(instances, %{}, fn inst ->
            ms = div(inst["total_us"] || 0, 1000)
            {{inst["elixir"], inst["otp"]}, ms}
          end)

        max_duration_ms =
          durations_by_ver
          |> Map.values()
          |> Enum.max(fn -> 0 end)

        avg_ms = if test_count > 0, do: div(max_duration_ms, test_count), else: 0
        max_test_ms = Enum.max(Enum.map(instances, &div(&1["max_us"] || 0, 1000)), fn -> 0 end)

        statuses = Enum.map(instances, & &1["status"])
        all_passed? = Enum.all?(statuses, &(&1 == "passed"))
        status = if all_passed?, do: "passed", else: "failed"

        %{
          module: mod,
          status: status,
          test_count: test_count,
          durations_by_ver: durations_by_ver,
          max_duration_ms: max_duration_ms,
          avg_ms: avg_ms,
          max_test_ms: max_test_ms
        }
      end)
      |> Enum.sort_by(& &1.max_duration_ms, :desc)

    if grouped_modules != [] do
      ver_header_cols = Enum.map_join(version_headers, " | ", fn {_, h} -> h end)
      ver_align_cols = Enum.map_join(version_headers, " | ", fn _ -> ":---" end)

      rows =
        Enum.map_join(grouped_modules, "\n", fn m ->
          ver_duration_cols =
            Enum.map_join(versions, " | ", fn ver ->
              case Map.get(m.durations_by_ver, ver) do
                nil -> "-"
                ms -> "`#{format_duration(ms)}`"
              end
            end)

          "| `#{m.module}` | #{m.status} | #{m.test_count} | #{ver_duration_cols} | `#{format_duration(m.avg_ms)}` | `#{format_duration(m.max_test_ms)}` |"
        end)

      """
      <details open>
      <summary><b>Module Breakdown</b></summary>

      | Module | Status | Tests | #{ver_header_cols} | Avg / Test | Max / Test |
      | :--- | :---: | :---: | #{ver_align_cols} | :--- | :--- |
      #{rows}

      </details>
      """
      |> String.trim()
    else
      ""
    end
  end

  defp format_service_timelines(service_summaries) do
    timelines =
      Enum.map(service_summaries, fn s ->
        modules = s["modules"] || []
        gantt = format_shard_mermaid_gantt(modules)
        {s["elixir"], s["otp"], gantt}
      end)
      |> Enum.reject(fn {_, _, gantt} -> gantt == "" end)

    if timelines != [] do
      content =
        Enum.map_join(timelines, "\n\n", fn {elixir, otp, gantt} ->
          """
          **Elixir #{elixir} / OTP #{otp}**

          #{gantt}
          """
        end)

      """
      <details open>
      <summary><b>Module Execution Timelines</b></summary>

      #{content}
      </details>
      """
      |> String.trim()
    else
      ""
    end
  end

  defp format_service_tests_table(service_summaries, versions, version_headers) do
    all_tests =
      for s <- service_summaries,
          t <- s["slowest_tests"] || [] do
        Map.merge(t, %{
          "elixir" => s["elixir"],
          "otp" => s["otp"]
        })
      end

    grouped_tests =
      all_tests
      |> Enum.group_by(fn t -> {t["module"], t["name"]} end)
      |> Enum.map(fn {{mod, name}, instances} ->
        first = hd(instances)

        durations_by_ver =
          Enum.into(instances, %{}, fn inst ->
            ms = inst["duration_ms"] || div(inst["time_us"] || 0, 1000)
            {{inst["elixir"], inst["otp"]}, ms}
          end)

        max_duration_ms =
          durations_by_ver
          |> Map.values()
          |> Enum.max(fn -> 0 end)

        statuses = Enum.map(instances, & &1["status"])
        all_passed? = Enum.all?(statuses, &(&1 == "passed"))
        status = if all_passed?, do: "passed", else: "failed"

        %{
          module: mod,
          name: name,
          file: first["file"],
          line: first["line"],
          durations_by_ver: durations_by_ver,
          max_duration_ms: max_duration_ms,
          status: status
        }
      end)
      |> Enum.sort_by(& &1.max_duration_ms, :desc)

    if grouped_tests != [] do
      ver_header_cols = Enum.map_join(version_headers, " | ", fn {_, h} -> h end)
      ver_align_cols = Enum.map_join(version_headers, " | ", fn _ -> ":---" end)

      rows =
        Enum.map_join(grouped_tests, "\n", fn t ->
          ver_duration_cols =
            Enum.map_join(versions, " | ", fn ver ->
              case Map.get(t.durations_by_ver, ver) do
                nil -> "-"
                ms -> "`#{format_duration(ms)}`"
              end
            end)

          "| #{t.status} | `#{format_duration(t.max_duration_ms)}` | #{ver_duration_cols} | #{escape_markdown(t.name)} | `#{t.module}` | `#{t.file}:#{t.line}` |"
        end)

      """
      <details open>
      <summary><b>Test Durations (Slowest to Fastest)</b></summary>

      | Status | Max Duration | #{ver_header_cols} | Test | Module | Location |
      | :---: | :--- | #{ver_align_cols} | :--- | :--- | :--- |
      #{rows}

      </details>
      """
      |> String.trim()
    else
      ""
    end
  end

  defp format_shard_mermaid_gantt(modules) do
    sorted_modules =
      Enum.sort_by(modules, fn m ->
        s = m["start_ms"] || 0
        f = m["finish_ms"] || s
        {s, f, m["module"]}
      end)

    lanes =
      Enum.reduce(sorted_modules, [], fn item, acc_lanes ->
        assign_to_lane(acc_lanes, item, [])
      end)
      |> Enum.map(&Enum.reverse/1)

    slowest_mod =
      Enum.max_by(
        modules,
        fn m -> (m["finish_ms"] || m["start_ms"] || 0) - (m["start_ms"] || 0) end,
        fn -> nil end
      )

    slowest_mod_name = slowest_mod && slowest_mod["module"]

    section_rows =
      lanes
      |> Enum.with_index(1)
      |> Enum.map(fn {lane, idx} ->
        tasks =
          Enum.map(lane, fn m ->
            module_name = format_gantt_module_name(m["module"])
            s = m["start_ms"] || 0
            f = m["finish_ms"] || s
            duration_ms = max(1000, f - s)
            finish_ms = s + duration_ms

            start_str = format_gantt_time(s)
            finish_str = format_gantt_time(finish_ms)
            tag = if m["module"] == slowest_mod_name, do: ":crit, active,", else: ":active,"

            "    #{module_name} #{tag} #{start_str}, #{finish_str}"
          end)

        "    section Lane #{idx}\n" <> Enum.join(tasks, "\n")
      end)

    """
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
    """
    |> String.trim()
  end

  defp assign_to_lane([], item, acc) do
    Enum.reverse([[item] | acc])
  end

  defp assign_to_lane(
         [[last_item | _] = lane | rest],
         item,
         acc
       ) do
    last_finish = last_item["finish_ms"] || last_item["start_ms"] || 0
    item_start = item["start_ms"] || 0

    if last_finish <= item_start do
      Enum.reverse(acc) ++ [[item | lane] | rest]
    else
      assign_to_lane(rest, item, [lane | acc])
    end
  end

  defp format_gantt_module_name(nil), do: "Unknown"

  defp format_gantt_module_name(mod) do
    mod
    |> to_string()
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

  defp format_version_headers(versions) do
    short_versions =
      Enum.map(versions, fn {elixir, _otp} ->
        short_version(elixir)
      end)

    unique? = length(Enum.uniq(short_versions)) == length(versions)

    Enum.map(versions, fn {elixir, otp} ->
      label = if unique?, do: short_version(elixir), else: elixir
      {{elixir, otp}, "Duration (#{label})"}
    end)
  end

  defp short_version(version) do
    version
    |> to_string()
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end

  defp sort_shards(shards) do
    Enum.sort_by(shards, fn s ->
      idx = Enum.find_index(@service_order, &(&1 == s["service"]))
      {idx || 99, s["service"]}
    end)
  end

  defp shard_status_cell(shard) do
    failures = shard["total_failures"] || 0
    if failures == 0, do: "passed", else: "**failed (#{failures})**"
  end

  defp format_shard_slowest(nil), do: "-"
  defp format_shard_slowest([]), do: "-"

  defp format_shard_slowest([slowest | _]) do
    format_test_desc(slowest)
  end

  defp format_test_desc(nil), do: "-"

  defp format_test_desc(test) do
    name = escape_markdown(test["name"] || "unknown")
    mod = test["module"] || "unknown"
    dur = format_duration(test["duration_ms"] || 0)
    "`#{mod}`: #{truncate_text(name, 45)} (`#{dur}`)"
  end

  defp service_name("postgresql"), do: "PostgreSQL"
  defp service_name("mysql"), do: "MySQL"
  defp service_name("mssql"), do: "MSSQL"
  defp service_name("none"), do: "sqlite3 + no-db"
  defp service_name(other), do: to_string(other)

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

  defp truncate_text(text, max_len) do
    if String.length(text) > max_len do
      String.slice(text, 0, max_len - 3) <> "..."
    else
      text
    end
  end

  defp escape_markdown(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("|", "\\|")
    |> String.replace("\r\n", " ")
    |> String.replace("\n", " ")
  end
end

Phoenix.Integration.AggregateSummary.run(System.argv())
