## Elixir guidelines

- Boolean operators: `and` / `or` vs `&&` / `||`

  Prefer using `&&` and `||` in most situations.

  The operators `and` / `or` require the **left-hand side to be a boolean** (`true` or `false`). If the left side is not a boolean, Elixir raises an `ArgumentError`.

  The operators `&&` / `||` accept **any value** and follow Elixir truthiness rules (`false` and `nil` are falsy, everything else is truthy). Because many Elixir expressions return non-boolean values, `&&` / `||` are usually the safer choice.

  Rule of thumb:
  - Use `&&` and `||` when the left side may return **any value** (`nil`, struct, number, etc).
  - Use `and` / `or` only when **both sides are guaranteed to be boolean expressions**.

  **Never do this (invalid)**:

      user = Repo.get(User, id)
      user and user.active

  `user` may be a struct or `nil`, which will raise an error with `and`.

  **Prefer this**:

      user = Repo.get(User, id)
      user && user.active

  `&&` safely handles `nil` or other non-boolean values.

  Boolean-only logic is still fine with `and`:

      is_admin = user.role == :admin
      is_active = user.active

      is_admin and is_active

  Both sides are boolean expressions, so `and` is acceptable.

  When working with changesets or database results, expressions often return structs or `nil`, not booleans.

  **Avoid this**:

      changeset = Accounts.change_user(user)

      changeset.valid? and Repo.insert(changeset)

  `Repo.insert/1` returns `{:ok, struct}` or `{:error, changeset}`, not a boolean.

  **Prefer this**:

      changeset = Accounts.change_user(user)

      changeset.valid? && Repo.insert(changeset)

  Another common case:

      user = Repo.get(User, id)
      user && user.active

  This safely handles the case where the user is not found (`nil`).

  When in doubt, use `&&` and `||`. Only use `and` / `or` when you are certain both operands are booleans.

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages

