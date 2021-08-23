# Asset Management

Beside producing HTML, most web applications have various assets (Javascript, CSS, images, fonts and so on).

Phoenix applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://hexdocs.pm/esbuild/Esbuild.html).

This direct integration with esbuild means that newly generated applications do not have dependencies on Node.js or an external build system (e.g. Webpack).

## Custom Builds

There are cases where you will want to customize your assets build to use another tool, or use esbuild in ways that go beyond the possibilities of the default system.

The main changes that you will need to make are:

1. Change the `assets.deploy` task defined in `mix.exs`,
2. Replace the `esbuild` configuration in `config/config.exs` and `config/dev.exs`,
3. Remove the `esbuild` dependency from `mix.exs`,
4. Unlock the `esbuild` dependency:

```console
$ mix deps.unlock esbuild
```

## A Custom esbuild Setup

Phoenix's default configuration of esbuild (via the Elixir wrapper) does not allow you to use [esbuild plugins](https://esbuild.github.io/plugins/).
If you want to use an esbuild plugin, for example to compile SASS files to CSS, you can replace the default build system with a custom build script.

The following is an example of a custom build using esbuild via Node.JS.

First of all, you'll need to install Node.js in development and make it available for your production build step.

Then you'll need to add esbuild to your Node packages:

```console
npm install esbuild --save-dev
```

or, for Yarn:

```console
yarn add --dev esbuild
```

Next, add a custom Javascript build script. We'll call the example `assets/build.js`:

```js
const esbuild = require('esbuild')

const bundle = true
const logLevel = process.env.ESBUILD_LOG_LEVEL || 'silent'
const watch = !!process.env.ESBUILD_WATCH

const plugins = [
  // Add and configure plugins here
]

const promise = esbuild.build({
  entryPoints: ['js/app.js'],
  bundle,
  target: 'es2016',
  plugins,
  outdir: '../priv/static/assets',
  logLevel,
  watch
})

if (watch) {
  promise.then(_result => {
    process.stdin.on('close', () => {
      process.exit(0)
    })

    process.stdin.resume()
  })
}
```

This script works both for development (in 'watch' mode) and for the production build (the default).
For development, we just need to set the environment variable `ESBUILD_WATCH`.

Modify `config/dev.exs` so that the script is run whenever you change files:

```elixir
config :hello, HelloWeb.Endpoint,
  ...
  watchers: [
    node: [
      "build.js",
      cd: Path.expand("../assets", __DIR__),
      env: %{"ESBUILD_LOG_LEVEL" => "silent", "ESBUILD_WATCH" => "1"}
    ]
  ],
  ...
```

Modify the `assets.deploy` task in `mix.exs`:

```elixir
  defp aliases do
    [
      ...
      "assets.deploy": ["cmd --cd assets node build.js", "phx.digest"]
    ]
  end
```

## Disabling Asset Management

If you are writing an API, or for some other reason you do not need to serve any assets, you can disable asset management completely.

1. Remove the `esbuild` configuration in `config/config.exs` and `config/dev.exs`,
2. Remove the `assets.deploy` task defined in `mix.exs`,
3. Remove the `esbuild` dependency from `mix.exs`,
4. Unlock the `esbuild` dependency:

```console
$ mix deps.unlock esbuild
```
