To prepare an application to serve requests over SSL, we need to add a little bit of configuration and two environment variables. In order for SSL to actually work, we'll need a key file and certificate file from a certificate authority. The environment variables that we'll need are paths to those two files.

The configuration consists of a new `https:` key for our endpoint whose value is a keyword list of port, path to the key file, and path to the cert (pem) file. If we add the `otp_app:` key whose value is the name of our application, Plug will begin to look for them at the root of our application. We can then put those files in our `priv` directory and set the paths to `priv/our_keyfile.key` and `priv/our_cert.crt`.

Here's an example configuration from `config/prod.exs`.

```elixir
use Mix.Config

. . .
config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com"],
  cache_static_manifest: "priv/static/manifest.json",
  https: [port: 443,
          otp_app: :hello_phoenix,
          keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
          certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),
          cacertfile: System.get_env("INTERMEDIATE_CERTFILE_PATH") # OPTIONAL Key for intermediate certificates
          ]

```

Without the `otp_app:` key, we need to provide absolute paths to the files wherever they are on the filesystem in order for Plug to find them.

```elixir
Path.expand("../../../some/path/to/ssl/key.pem", __DIR__)
```
