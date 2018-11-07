# Release Instructions

**IMPORTANT**: when building the archive, it must be done in the minimum supported Erlang and Elixir versions.

  1. Check related deps for required version bumps and compatibility (`phoenix_ecto`, `phoenix_pubsub_redis`, `phoenix_html`)
  2. Bump version in related files below
  3. Update `phoenix_dep` in `installer/lib/phoenix_new.ex` and `installer/lib/phx_new/generator.ex` to "~> version to be released"
  4. Run tests, commit, push code
  5. Publish `phx_new` and `phoenix` packages and docs after pruning any extraneous uncommitted files
  6. Test installer by generating a new app, running `mix deps.get`, and compiling
  7. Start -dev version in related files below
  8. Update `phoenix_dep` in `installer/lib/phoenix_new.ex` back to git
  9. Publish to `npm` with `npm publish`
  10. Replace `master` for `source_url_pattern` in `installer/mix.exs`

## Files with version

  * `CHANGELOG`
  * `mix.exs`
  * `installer/mix.exs`
  * `installer/README.md`
  * `package.json`
  * `assets/package.json`
  * `guides/introduction/installation.md`
