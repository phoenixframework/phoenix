# Phoenix Router pipe_through Ordering Issue #6139

## Problem Description
Currently, Phoenix allows `pipe_through` to be called after routes are defined within a scope, which can lead to confusing behavior where some routes don't get the expected pipelines applied.

## Current Behavior (Confusing)
```elixir
scope "/" do
  get "/", HomeController, :index           # Only gets default scope pipelines
  pipe_through [:browser]                   # This affects routes AFTER it
  get "/settings", UserController, :edit    # Gets browser pipeline
end
```

## Expected Behavior (What we want)
- `pipe_through` should only be allowed at the beginning of a scope
- If any routes are defined before `pipe_through`, it should raise an error
- This prevents the common pitfall of thinking all routes get the pipeline

## Implementation Plan
1. Track in the router scope when routes have been defined
2. Raise an error if `pipe_through` is called after routes exist
3. Add test cases for both valid and invalid scenarios
4. Update error message to guide users to proper usage

## Files to Modify
- `lib/phoenix/router.ex` - Add validation logic
- `test/phoenix/router/routing_test.exs` - Add test cases

## Test Cases Needed
- ✅ Valid: `pipe_through` before any routes
- ❌ Invalid: `pipe_through` after routes defined
- ❌ Invalid: Multiple `pipe_through` calls with routes in between
