# Asset Management

Beside producing HTML, most web applications have various assets (JavaScript, CSS, images, fonts and so on).

From Phoenix v1.6, new applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://github.com/phoenixframework/esbuild). This direct integration with `esbuild` means that newly generated applications do not have dependencies on Node.js or an external build system (e.g. Webpack).

Your JavaScript is typically placed at "assets/js/app.js" and `esbuild` will extract it to "priv/static/assets/app.js". In development, this is done automatically via the `esbuild` watcher. In production, this is done by running `mix assets.deploy`.

`esbuild` can also handle your CSS files can also be handled by `esbuild`. For this, there is typically an `import "../css/app.css"` at the top of your "assets/js/app.js". We will explore alternatives below.

Finally, all other assets, that usually don't have to be preprocessed, go directly to "priv/static".

## Third-party JS packages

If you want to import JavaScript dependencies, you have two options to add them to your application:

  1. Vendor those dependencies inside your project and import them in your "assets/js/app.js" using a relative path:

         import topbar from "../vendor/topbar"

  2. Call `npm install topbar --save` inside your assets directory and `esbuild` will be able to automatically pick them up:

         import topbar from "topbar"

## CSS

`esbuild` has basic support for CSS. If you import a `.css` file at the top of your main `.js` file, `esbuild` will also bundle it, and write it to the same directory as your final `app.js`. That's what Phoenix does by default:

```js
import "../css/app.css"
```

However, if you want to use a CSS framework, such as SASS or Tailwind, you will need to use a separate tool. Here are some options to do so:

  * You can use `esbuild` plugins (requires `npm`). See the "Esbuild plugins" section below

  * If you want SASS, you can bring [standalone SASS](https://github.com/CargoSense/dart_sass) to your project, without a need for external dependencies (similar to esbuild).

  * You can bring Node.JS + `npm` to your application and install any package you want, typically working directly with their command line interface. See [this pull request on how to add Alpine + Tailwind](https://github.com/josevalim/phx_esbuild_demo/pull/3).

Don't forget to remove the `import "../css/app.css"` from your JavaScript file when doing so.

## Esbuild plugins

Phoenix's default configuration of `esbuild` (via the Elixir wrapper) does not allow you to use [esbuild plugins](https://esbuild.github.io/plugins/). If you want to use an esbuild plugin, for example to compile SASS files to CSS, you can replace the default build system with a custom build script.

The following is an example of a custom build using esbuild via Node.JS. First of all, you'll need to install Node.js in development and make it available for your production build step.

Then you'll need to add `esbuild` to your Node.js packages and the Phoenix packages. Inside the `assets` directory, run:

```console
$ npm install esbuild --save-dev
$ npm install ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view --save
```

or, for Yarn:

```console
$ yarn add --dev esbuild
$ yarn add ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view
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

This script works both for development (in "watch" mode) and for the production build (the default). For development, we just need to set the environment variable `ESBUILD_WATCH`.

Modify `config/dev.exs` so that the script runs whenever you change files, replacing the existing `:esbuild` configuration under `watchers`:

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

Modify the `aliases` task in `mix.exs` to install `npm` packages during `mix setup` and use the new `esbuild` on `mix assets.deploy`:

```elixir
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      ...,
      "assets.deploy": ["cmd --cd assets node build.js", "phx.digest"]
    ]
  end
```

Finally, remove the `esbuild` configuration from `config/config.exs` and remove the dependency from the `deps` function in your `mix.exs`, and you are done!

## Removing esbuild

If you are writing an API, or for some other reason you do not need to serve any assets, you can disable asset management completely.

1. Remove the `esbuild` configuration in `config/config.exs` and `config/dev.exs`,
2. Remove the `assets.deploy` task defined in `mix.exs`,
3. Remove the `esbuild` dependency from `mix.exs`,
4. Unlock the `esbuild` dependency:

```console
$ mix deps.unlock esbuild
```
