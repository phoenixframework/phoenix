# Release Instructions

  1. Do *not* start a release without syncing with the docs team
  2. Bump version in CHANGELOG, mix.exs and installer/mix.exs
  3. Update phoenix reference in installer/templates/new/mix.exs to package
  4. Run tests, commit, push branch and tags
  5. Run mix archive.build inside installer/ directory to build new installer
  6. Push package and docs to hex
  7. Update CHANGELOG, mix.exs to -dev
  8. Update phoenix reference in installer/templates/new/mix.exs back to git
