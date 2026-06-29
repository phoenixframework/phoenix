# Changelog for v1.9

## v1.9.0-dev

### Potential breaking changes

  * [Phoenix.Router] Phoenix will now group your routes per verb during compilation. This improves compilation times for large routers with no performance cost at runtime. However, this change implies that wildcard routes are always matched last, which changes the semantics of dead routes. If you had this code:

      match :*, "/foo"
      get "/foo"

  The second route would never be matched but it will now be as part of this change. However, note that `get "/foo"` should not exist in the first place: it should be either removed or moved first. We recommend checking for any `match :*` in your router and moving them to the end of the file.

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
