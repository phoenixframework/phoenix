# Phoenix Presence Generator Issue #6287

## Problem
When running `mix phx.gen.presence` in an umbrella app, it generates the wrong PubSub server name.

## Current Behavior
For umbrella app `hello` with web app `hello_web`, it generates:
```elixir
defmodule HelloWeb.Presence do
  use Phoenix.Presence,
    otp_app: :hello_web,
    pubsub_server: HelloWeb.PubSub  # <-- WRONG
end
```

## Expected Behavior
It should generate:
```elixir
defmodule HelloWeb.Presence do
  use Phoenix.Presence,
    otp_app: :hello_web,
    pubsub_server: Hello.PubSub     # <-- CORRECT
end
```

## Root Cause
In `lib/mix/tasks/phx.gen.presence.ex` line 33:
```elixir
pubsub_server: Module.concat(inflections[:base], "PubSub")
```

The issue is that `inflections[:base]` returns the web module name (`HelloWeb`) instead of the main app module name (`Hello`) for umbrella apps.

## Solution
Need to use the context app module name instead of the base module name for the PubSub server in umbrella apps.

## Files to modify
1. `lib/mix/tasks/phx.gen.presence.ex` - Fix the pubsub_server binding logic
