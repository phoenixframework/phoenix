# Changelog for v1.9

## v1.9.0-dev

### Enhancements

  * [Phoenix.Router] Add `use Phoenix.Router, group_by: :verb` to group routes per verb during compilation. This can improve compilation times for large routers with no performance cost at runtime. When enabled, all `match :*` and `forward` routes must be defined at the end of the router, otherwise compilation fails with a list of violations

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
