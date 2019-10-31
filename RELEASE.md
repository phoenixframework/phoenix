# Release Instructions

  1. Check related deps for required version bumps and compatibility (`phoenix_ecto`, `phoenix_pubsub_redis`, `phoenix_html`)
  2. Update `phoenix_dep` in `installer/lib/phx_new/generator.ex` to release
  3. Bump version in related files below
  4. Run tests, commit, push code
  5. Publish `phx_new` and `phoenix` packages and docs after pruning any extraneous uncommitted files
  6. Test installer by generating a new app, running `mix deps.get`, and compiling
  7. Publish to `npm` with `npm publish`
  8. Start -dev version in related files below
  9. Update `phoenix_dep` in `installer/lib/phx_new/generator.ex` back to git

## Files with version

  * `CHANGELOG`
  * `mix.exs`
  * `installer/mix.exs`
  * `installer/README.md`
  * `package.json`
  * `assets/package.json`
  * `guides/introduction/installation.md`
