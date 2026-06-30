## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied

## MongoDB (adapter: `Mongo.Ecto`)

When the project uses `--database mongo`:

- **Primary keys must be `:binary_id`** — configured automatically via `config :app, :generators, binary_id: true`. All `mix phx.gen.*` commands honour this; no `--binary-id` flag needed.
- **Ecto `join` is not supported** — `mongodb_ecto` does not translate Ecto `join` clauses. Use embedded schemas (`embeds_one`, `embeds_many`) for nested data, or MongoDB aggregations (`$lookup`) via the `mongodb_driver` directly for cross-collection queries.
- **Migrations create collections and indexes**, not tables. `create table(:name)` → MongoDB collection. `add :col, :type` → no-op (schema-less).
- **Test isolation** uses `Mongo.Ecto.truncate(Repo)` before each test (called in `DataCase.setup/1`), not `Ecto.Adapters.SQL.Sandbox`.
- **Connection string** uses `mongo_url:` config key. In production, set `DATABASE_URL` to a MongoDB URI (`mongodb://...` or `mongodb+srv://...`).
- **Atlas** — swap `DATABASE_URL` to your Atlas connection string; no code changes needed.
- `:decimal` type is not supported by `mongodb_ecto`.
