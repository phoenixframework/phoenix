# Script to aggregate integration test JSON summaries into a Markdown report.
#
# Usage:
#   elixir integration_test/aggregate_summary.exs <directory_with_json_files>
#

defmodule Phoenix.Integration.AggregateSummary do
  defmodule Summary do
    defstruct [
      :job,
      :job_label,
      :job_sort_key,
      :elixir,
      :otp,
      :version_key,
      :total,
      :failed,
      :invalid,
      :passed?,
      :wall_time_ms,
      modules: [],
      tests: []
    ]
  end

  defmodule ModuleRun do
    defstruct [
      :module,
      :timeline_name,
      :status,
      :test_count,
      :duration_ms,
      :max_ms,
      :start_ms,
      :finish_ms,
      :elixir,
      :otp
    ]
  end

  defmodule TestRun do
    defstruct [
      :name,
      :module,
      :status,
      :duration_ms,
      :location,
      :job,
      :elixir,
      :otp
    ]
  end

  defmodule AggregatedModule do
    defstruct [
      :module,
      :timeline_name,
      :status,
      :test_count,
      :durations,
      :max_duration_ms,
      :max_test_ms
    ]
  end

  defmodule AggregatedTest do
    defstruct [
      :name,
      :module,
      :status,
      :durations,
      :max_duration_ms,
      :location,
      :job
    ]
  end

  def run([summaries_dir]) do
    case Path.wildcard(Path.join(summaries_dir, "**/*.json")) do
      [] ->
        IO.puts(:stderr, "No summary JSON files found in #{summaries_dir}")
        System.halt(1)

      json_files ->
        json_files
        |> Enum.map(fn file ->
          file
          |> File.read!()
          |> JSON.decode!()
          |> parse_summary()
        end)
        |> format_report()
        |> IO.puts()
    end
  end

  def run(_argv) do
    IO.puts(
      :stderr,
      "Usage: elixir integration_test/aggregate_summary.exs <directory_with_json_files>"
    )

    System.halt(1)
  end

  def parse_summary(%{
        "config" => %{"elixir" => elixir, "otp" => otp} = config,
        "suite_result" => %{"total" => total, "failed" => failed, "invalid" => invalid},
        "wall_time_ms" => wall_time_ms,
        "modules" => modules,
        "tests" => tests
      }) do
    job = config["job"] || "job"

    modules =
      Enum.map(modules, fn %{
                             "module" => module,
                             "status" => status,
                             "test_count" => test_count,
                             "duration_ms" => duration_ms,
                             "max_ms" => max_ms,
                             "start_ms" => start_ms,
                             "finish_ms" => finish_ms
                           } ->
        %ModuleRun{
          module: module,
          timeline_name: timeline_name(module),
          status: parse_status(status),
          test_count: test_count,
          duration_ms: duration_ms,
          max_ms: max_ms,
          start_ms: start_ms,
          finish_ms: finish_ms,
          elixir: elixir,
          otp: otp
        }
      end)

    tests =
      Enum.map(tests, fn %{
                           "name" => name,
                           "module" => module,
                           "status" => status,
                           "duration_ms" => duration_ms,
                           "location" => location
                         } ->
        %TestRun{
          name: name,
          module: module,
          status: parse_status(status),
          duration_ms: duration_ms,
          location: location,
          job: job,
          elixir: elixir,
          otp: otp
        }
      end)

    %Summary{
      job: job,
      job_label: format_job(job),
      job_sort_key: job_sort_key(job),
      elixir: elixir,
      otp: otp,
      version_key: {parse_version(elixir), parse_version(otp)},
      total: total,
      failed: failed,
      invalid: invalid,
      passed?: failed == 0 and invalid == 0,
      wall_time_ms: wall_time_ms,
      modules: modules,
      tests: tests
    }
  end

  def format_report(summaries) do
    summaries = sort_summaries(summaries)

    [
      "## Phoenix Integration Tests Summary",
      format_summary_table(summaries),
      format_matrix_table(summaries),
      format_slowest_tests_table(summaries),
      format_jobs_details(summaries)
    ]
    |> Enum.join("\n\n")
  end

  defp format_summary_table(summaries) do
    total_versions = length(extract_versions(summaries))
    total_jobs = length(summaries)

    passed? = passed?(summaries)
    overall_status = if passed?, do: "Passed", else: "Failed"

    overall_wall_time =
      summaries
      |> Enum.map(& &1.wall_time_ms)
      |> Enum.max()
      |> format_duration()

    """
    | Elixir/OTP Versions | Total Jobs | Overall Status | Wall Time |
    | :---: | :---: | :---: | :---: |
    | #{total_versions} | #{total_jobs} | #{overall_status} | `#{overall_wall_time}` |
    """
    |> String.trim()
  end

  defp format_matrix_table(summaries) do
    table_rows =
      summaries
      |> Enum.chunk_by(&{&1.elixir, &1.otp})
      |> Enum.map_join("\n", &format_matrix_version/1)

    """
    | Elixir/OTP | Job | Status | Tests | Wall Time | Slowest Test |
    | :--- | :--- | :---: | :---: | :---: | :--- |
    #{table_rows}
    """
    |> String.trim()
  end

  defp format_matrix_version([%Summary{elixir: elixir, otp: otp} | _] = jobs) do
    status_str = format_summary_status(jobs)

    total = Enum.sum(Enum.map(jobs, & &1.total))

    max_wall_time =
      jobs
      |> Enum.map(& &1.wall_time_ms)
      |> Enum.max()
      |> format_duration()

    overall_slowest =
      jobs
      |> Enum.flat_map(& &1.tests)
      |> Enum.max_by(& &1.duration_ms)
      |> format_test_desc()

    combined_row =
      "| **#{elixir}/#{otp}** | **Combined** | #{status_str} | #{total} | `#{max_wall_time}` | #{overall_slowest} |"

    job_rows =
      Enum.map_join(jobs, "\n", fn job_summary ->
        job_label = job_summary.job_label
        status = format_summary_status(job_summary)
        total = job_summary.total
        wall_time = format_duration(job_summary.wall_time_ms)
        slowest = format_test_desc(hd(job_summary.tests))

        "| | #{job_label} | #{status} | #{total} | `#{wall_time}` | #{slowest} |"
      end)

    "#{combined_row}\n#{job_rows}"
  end

  defp format_slowest_tests_table(summaries) do
    versions = extract_versions(summaries)
    {duration_header, duration_align} = duration_column_headers(versions)

    rows =
      summaries
      |> Enum.flat_map(& &1.tests)
      |> aggregate_tests()
      |> Enum.take(10)
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {%AggregatedTest{} = t, idx} ->
        status = format_status(t.status)
        durations = format_duration_cells(t, versions)
        test = escape_markdown(t.name)
        job = format_job(t.job)

        "| #{idx} | #{status} | #{durations} | #{test} | `#{t.module}` | #{job} | `#{t.location}` |"
      end)

    """
    <details open>
    <summary><b>Top 10 Slowest Tests</b></summary>

    | # | Status | #{duration_header} | Test | Module | Job | Location |
    | :---: | :---: | #{duration_align} | :--- | :--- | :---: | :--- |
    #{rows}

    </details>
    """
    |> String.trim()
  end

  defp format_jobs_details(summaries) do
    versions = extract_versions(summaries)

    summaries
    |> Enum.sort_by(&{&1.job_sort_key, &1.version_key})
    |> Enum.chunk_by(& &1.job)
    |> Enum.map_join("\n\n", fn job_summaries ->
      format_job_details(job_summaries, versions)
    end)
  end

  defp format_job_details([%Summary{job_label: job_label} | _] = job_summaries, versions) do
    max_tests =
      job_summaries
      |> Enum.map(& &1.total)
      |> Enum.max()

    status_label = format_summary_status(job_summaries)

    wall_times_summary =
      Enum.map_join(job_summaries, " | ", fn s ->
        "#{format_duration(s.wall_time_ms)} in #{s.elixir}"
      end)

    timelines_section = format_job_timelines(job_summaries)
    modules_section = format_job_modules_table(job_summaries, versions)
    tests_section = format_job_tests_table(job_summaries, versions)

    sections =
      [timelines_section, modules_section, tests_section]
      |> Enum.join("\n\n")

    """
    <details#{unless passed?(job_summaries), do: " open"}>
    <summary><b>#{job_label} Details</b>: #{status_label} — #{max_tests} tests (#{wall_times_summary})</summary>

    #{sections}
    </details>
    """
    |> String.trim()
  end

  defp format_job_timelines(job_summaries) do
    content =
      Enum.map_join(job_summaries, "\n\n", fn s ->
        gantt = format_mermaid_gantt(s.modules)

        """
        **#{s.elixir}/#{s.otp}**

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
  end

  defp format_job_modules_table(job_summaries, versions) do
    {duration_header, duration_align} = duration_column_headers(versions)

    rows =
      job_summaries
      |> Enum.flat_map(& &1.modules)
      |> aggregate_modules()
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {%AggregatedModule{} = m, idx} ->
        status = format_status(m.status)
        durations = format_duration_cells(m, versions)

        module = "`#{m.module}`<br><small>Timeline: `#{m.timeline_name}`</small>"
        max_test = format_duration(m.max_test_ms)

        "| #{idx} | #{status} | #{durations} | #{module} | #{m.test_count} | `#{max_test}` |"
      end)

    """
    <details open>
    <summary><b>Module Durations</b></summary>

    | # | Status | #{duration_header} | Module | Tests | Max / Test |
    | :---: | :---: | #{duration_align} | :--- | :---: | :--- |
    #{rows}

    </details>
    """
    |> String.trim()
  end

  defp format_job_tests_table(job_summaries, versions) do
    {duration_header, duration_align} = duration_column_headers(versions)

    rows =
      job_summaries
      |> Enum.flat_map(& &1.tests)
      |> aggregate_tests()
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {%AggregatedTest{} = t, idx} ->
        status = format_status(t.status)
        durations = format_duration_cells(t, versions)
        test = escape_markdown(t.name)

        "| #{idx} | #{status} | #{durations} | #{test} | `#{t.module}` | `#{t.location}` |"
      end)

    """
    <details open>
    <summary><b>Test Durations</b></summary>

    | # | Status | #{duration_header} | Test | Module | Location |
    | :---: | :---: | #{duration_align} | :--- | :--- | :--- |
    #{rows}

    </details>
    """
    |> String.trim()
  end

  defp format_mermaid_gantt(modules) do
    sorted_modules = Enum.sort_by(modules, &{&1.start_ms, &1.finish_ms, &1.module})

    lanes =
      Enum.reduce(sorted_modules, [], fn item, acc_lanes ->
        assign_to_lane(acc_lanes, item)
      end)
      |> Enum.map(&Enum.reverse/1)

    slowest_mod = Enum.max_by(modules, & &1.duration_ms)
    slowest_mod_name = slowest_mod.module

    section_rows =
      lanes
      |> Enum.with_index(1)
      |> Enum.map(fn {lane, idx} ->
        tasks =
          Enum.map(lane, fn %ModuleRun{} = item ->
            duration_ms = max(1000, item.finish_ms - item.start_ms)
            finish_ms = item.start_ms + duration_ms

            start_str = format_gantt_time(item.start_ms)
            finish_str = format_gantt_time(finish_ms)
            tags = if item.module == slowest_mod_name, do: "crit, active", else: "active"

            "    #{item.timeline_name} :#{tags}, #{start_str}, #{finish_str}"
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

  defp assign_to_lane(lanes, %ModuleRun{} = item) do
    case Enum.split_while(lanes, fn [%ModuleRun{} = head | _] ->
           head.finish_ms > item.start_ms
         end) do
      {prev_lanes, [compatible_lane | next_lanes]} ->
        prev_lanes ++ [[item | compatible_lane] | next_lanes]

      {all_occupied, []} ->
        all_occupied ++ [[item]]
    end
  end

  defp aggregate_modules(module_runs) do
    module_runs
    |> Enum.group_by(& &1.module)
    |> Enum.map(fn {mod, instances} ->
      first = hd(instances)
      test_count = Enum.max(Enum.map(instances, & &1.test_count))

      durations =
        Enum.into(instances, %{}, fn %ModuleRun{} = r ->
          {{r.elixir, r.otp}, r.duration_ms}
        end)

      max_duration_ms =
        durations
        |> Map.values()
        |> Enum.max()

      max_test_ms = Enum.max(Enum.map(instances, & &1.max_ms))
      status = aggregate_status(instances)

      %AggregatedModule{
        module: mod,
        timeline_name: first.timeline_name,
        status: status,
        test_count: test_count,
        durations: durations,
        max_duration_ms: max_duration_ms,
        max_test_ms: max_test_ms
      }
    end)
    |> Enum.sort_by(& &1.max_duration_ms, :desc)
  end

  defp aggregate_tests(test_runs) do
    test_runs
    |> Enum.group_by(&{&1.module, &1.name})
    |> Enum.map(fn {{mod, name}, instances} ->
      first = hd(instances)
      status = aggregate_status(instances)

      durations =
        Enum.into(instances, %{}, fn %TestRun{} = r ->
          {{r.elixir, r.otp}, r.duration_ms}
        end)

      max_duration_ms =
        durations
        |> Map.values()
        |> Enum.max()

      %AggregatedTest{
        module: mod,
        name: name,
        status: status,
        durations: durations,
        max_duration_ms: max_duration_ms,
        location: first.location,
        job: first.job
      }
    end)
    |> Enum.sort_by(& &1.max_duration_ms, :desc)
  end

  defp aggregate_status(instances) do
    cond do
      Enum.any?(instances, &(&1.status == :invalid)) -> :invalid
      Enum.any?(instances, &(&1.status == :failed)) -> :failed
      true -> :passed
    end
  end

  defp sort_summaries(summaries) do
    Enum.sort_by(summaries, &{&1.version_key, &1.job_sort_key})
  end

  defp extract_versions(summaries) do
    summaries
    |> Enum.map(&{&1.elixir, &1.otp})
    |> Enum.uniq()
  end

  defp parse_status("passed"), do: :passed
  defp parse_status("failed"), do: :failed
  defp parse_status("invalid"), do: :invalid

  defp timeline_name(mod) do
    mod
    |> String.replace_prefix("UmbrellaAppWith", "Umbrella")
    |> String.replace_prefix("AppWith", "")
    |> String.replace("Adapter", "")
    |> String.replace_suffix("Test", "")
  end

  defp job_sort_key("postgresql"), do: {0, "postgresql"}
  defp job_sort_key("mysql"), do: {1, "mysql"}
  defp job_sort_key("mssql"), do: {2, "mssql"}
  defp job_sort_key(other), do: {3, other}

  defp parse_version(version) do
    ~r/\d+|\D+/
    |> Regex.scan(version)
    |> Enum.map(fn [part] ->
      case Integer.parse(part) do
        {num, ""} -> num
        _ -> part
      end
    end)
  end

  defp duration_column_headers([_]), do: {"Duration", ":---"}

  defp duration_column_headers(versions) do
    headers =
      ["Max Duration" | Enum.map(versions, fn {elixir, _otp} -> "Duration (#{elixir})" end)]

    {Enum.join(headers, " | "), Enum.map_join(headers, " | ", fn _ -> ":---" end)}
  end

  defp format_duration_cells(%{max_duration_ms: max_ms}, [_]) do
    "`#{format_duration(max_ms)}`"
  end

  defp format_duration_cells(%{durations: durations, max_duration_ms: max_ms}, versions) do
    version_cols =
      Enum.map_join(versions, " | ", fn version ->
        case durations[version] do
          nil -> "-"
          ms -> "`#{format_duration(ms)}`"
        end
      end)

    "`#{format_duration(max_ms)}` | #{version_cols}"
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    total_seconds = round(ms / 1000)
    mins = div(total_seconds, 60)
    secs = rem(total_seconds, 60)

    if mins == 0 do
      "#{secs}s"
    else
      "#{mins}m #{pad_zero(secs)}s"
    end
  end

  defp format_gantt_time(ms) do
    total_seconds = div(ms, 1000)
    mins = pad_zero(div(total_seconds, 60))
    secs = pad_zero(rem(total_seconds, 60))

    "#{mins}:#{secs}"
  end

  defp pad_zero(int), do: int |> Integer.to_string() |> String.pad_leading(2, "0")

  defp format_job("postgresql"), do: "PostgreSQL"
  defp format_job("mysql"), do: "MySQL"
  defp format_job("mssql"), do: "MSSQL"
  defp format_job("none"), do: "SQLite3 + no-DB"
  defp format_job(other) when is_binary(other), do: String.capitalize(other)

  defp passed?(%Summary{passed?: passed?}), do: passed?
  defp passed?(summaries) when is_list(summaries), do: Enum.all?(summaries, &passed?/1)

  defp format_summary_status(%Summary{failed: f, invalid: i}), do: format_summary_status(f, i)

  defp format_summary_status(summaries) when is_list(summaries) do
    failed = Enum.sum(Enum.map(summaries, & &1.failed))
    invalid = Enum.sum(Enum.map(summaries, & &1.invalid))
    format_summary_status(failed, invalid)
  end

  defp format_summary_status(0, 0), do: "Passed"
  defp format_summary_status(f, 0), do: "Failed (#{f})"
  defp format_summary_status(0, i), do: "Invalid (#{i})"
  defp format_summary_status(f, i), do: "Failed (#{f}) / Invalid (#{i})"

  defp format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_test_desc(%TestRun{} = t) do
    duration = format_duration(t.duration_ms)
    truncated_name = t.name |> truncate_text(45) |> escape_markdown()
    "`#{t.module}`: #{truncated_name} (`#{duration}`)"
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
