## MongoDB

When the project uses `--database mongo` (adapter: `Mongo.Ecto`):

- **Primary keys must be `:binary_id`** — configured automatically via `config :app, :generators, binary_id: true`. All `mix phx.gen.*` commands honour this automatically; no `--binary-id` flag needed.
- **No SQL joins** — use embedded schemas (`embeds_one`, `embeds_many`) for nested data, or separate queries for associations.
- **Migrations create collections and indexes**, not tables. `create table(:name)` → MongoDB collection. `add :col, :type` → no-op (schema-less).
- **Test isolation** uses `Mongo.Ecto.truncate(Repo)` before each test, not `Ecto.Adapters.SQL.Sandbox`.
- **Connection string** uses `mongo_url:` config key. In production, set `DATABASE_URL` env var to a MongoDB URI (`mongodb://...` or `mongodb+srv://...`).
- **Atlas** — swap `DATABASE_URL` to your Atlas connection string; no code changes needed.
- `:decimal` type is not supported by `mongodb_ecto`.
