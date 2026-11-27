## Ecto Guidelines

- Use `redact: true` on sensitive schema fields to hide them when inspecting schemas and changesets. Once a value is passed as a query parameter, Ecto SQL can print it in the query log (`:debug` by default). Setting `log: false` in the Ecto Repo configuration or on an individual query disables query logging, but query telemetry handlers can still receive the value in `:params` or `:cast_params`; omit these fields when exporting query diagnostics.
- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
