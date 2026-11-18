## Elixir guidelines

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- **Never** use `DateTime.utc_now() |> DateTime.truncate(:second)`. **Always** use `DateTime.utc_now(:second)` instead
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Use `mix help <task_name|module_name|module.function>` to access their documentation
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`

## Test guidelines

- Always use `start_supervised!/1` to start processes in tests as it guarantees cleanup between tests
- Avoid `Process.alive?/1` to check if a process died, use `Process.monitor/1` instead
- Avoid `Process.sleep/1` in tests, use `_ = :sys.get_state/1` to ensure the process has handled prior messages (for LiveViews, you can use `render(view)`)
