# Release Instructions

**IMPORTANT**: when building the archive, it must be done in the minimum supported Erlang and Elixir versions.

  1. Check related deps for required version bumps and compatibility (`phoenix_ecto`, `phoenix_pubsub_redis`, `phoenix_html`)
  2. Bump version in related files below
  3. Update `phoenix_dep` in `installer/lib/phoenix_new.ex` to "~> version to be released"
  4. Run tests, commit, push code
  5. Publish packages and docs after pruning any extraneous uncommitted files
  6. Run `mix archive.build` and `mix archive.build -o phoenix_new.ez` inside "installer" directory to build new installers
  7. Copy new installers to "phoenixframework/archives" project
  8. Test installer by generating a new app, running `mix deps.get`, and compiling
  9. Start -dev version in related files below
  10. Update `phoenix_dep` in `installer/lib/phoenix_new.ex` back to git
  11. Publish to `npm` with `npm publish`

## Files with version

  * `CHANGELOG`
  * `mix.exs`
  * `installer/mix.exs`
  * `package.json`
