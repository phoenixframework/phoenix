# Release Instructions

  1. Do *not* start a release without syncing with the docs team
  2. Check related deps for required version bumps and compatibilitiy (`phoenix_ecto`, `phoenix_pubsub_redis`, `phoenix_html`)
  3. Bump version in CHANGELOG, mix.exs and installer/mix.exs
  4. Update `phoenix_dep` in installer/lib/phoenix_new.ex to "~> version to be released"
  5. Run tests, commit, push branch and tags
  6. Run mix archive.build inside installer/ directory to build new installer
  7. Test installer by generating a new app, running `mix deps.get`, and compiling
  8. Push package and docs to hex
  9. Update CHANGELOG, mix.exs to -dev
  10. Update `phoenix_dep` in installer/lib/phoenix_new.ex back to git
