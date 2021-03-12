# Release Instructions

  1. Check related deps for required version bumps and compatibility (`phoenix_ecto`, `phoenix_pubsub_redis`, `phoenix_html`)
  2. Bump version in related files below
  3. Run tests:
    - `mix test` in the root folder
    - `mix test` in the `installer/` folder
  4. Commit, push code
  5. Publish `phx_new` and `phoenix` packages and docs after pruning any extraneous uncommitted files
  6. Test installer by generating a new app, running `mix deps.get`, and compiling
  7. Publish to `npm` with `npm publish`
  8. Start -dev version in related files below

## Files with version

  * `CHANGELOG`
  * `mix.exs`
  * `installer/mix.exs`
  * `package.json`
  * `assets/package.json`
