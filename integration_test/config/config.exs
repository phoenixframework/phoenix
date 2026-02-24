import Config

# TODO: Remove the `json_library` check once `JSON` becomes the standard `Phoenix.json_library/1`
config :phoenix, :json_library, (if Code.ensure_loaded?(JSON), do: JSON, else: Jason)

config :swoosh, api_client: false

config :tailwind, :version, "4.1.12"

config :phoenix_live_view, enable_expensive_runtime_checks: true
