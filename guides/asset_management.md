# Asset Management

Beside producing HTML, most web applications have various assets (JavaScript, CSS, images, fonts and so on).

From Phoenix v1.7, new applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://github.com/phoenixframework/esbuild), and [tailwindcss](https://tailwindcss.com) via the [Elixir tailwindcss wrapper](https://github.com/phoenixframework/tailwind) for CSS. The direct integration with `esbuild` and `tailwind` means that newly generated applications do not have dependencies on Node.js or an external build system (e.g. Webpack).

Your JavaScript is typically placed at "assets/js/app.js" and `esbuild` will extract it to "priv/static/assets/app.js". In development, this is done automatically via the `esbuild` watcher. In production, this is done by running `mix assets.deploy`.

`esbuild` can also handle your CSS files, but by default `tailwind` handles all CSS building.

Finally, all other assets, that usually don't have to be preprocessed, go directly to "priv/static".

## Third-party JS packages

If you want to import JavaScript dependencies, you have two options to add them to your application:

1. Vendor those dependencies inside your project and import them in your "assets/js/app.js" using a relative path:

   ```js
   import topbar from "../vendor/topbar"
   ```

2. Call `npm install topbar --save` inside your assets directory and `esbuild` will be able to automatically pick them up:

   ```js
   import topbar from "topbar"
   ```

## CSS

By default, Phoenix generates CSS with the `tailwind` library, but esbuild has basic support for CSS which you can use if you aren't using tailwind. If you import a `.css` file at the top of your main `.js` file, `esbuild` will bundle it, and write it to the same directory as your final `app.js`.

```js
import "../css/app.css"
```

However, if you want to use a CSS framework, you will need to use a separate tool. Here are some options to do so:

  * You can use `esbuild` plugins (requires `npm`). See the "Esbuild plugins" section below

Don't forget to remove the `import "../css/app.css"` from your JavaScript file when doing so.

## Images, fonts, and external files

If you reference an external file in your CSS or JavaScript files, `esbuild` will attempt to validate and manage them, unless told otherwise.

For example, imagine you want to reference `priv/static/images/bg.png`, served at `/images/bg.png`, from your CSS file:

```css
body {
  background-image: url(/images/bg.png);
}
```

The above may fail with the following message:

```text
error: Could not resolve "/images/bg.png" (mark it as external to exclude it from the bundle)
```

Given the images are already managed by Phoenix, you need to mark all resources from `/images` (and also `/fonts`) as external, as the error message says. This is what Phoenix does by default for new apps since v1.6.1+. In your `config/config.exs`, you will find:

```elixir
args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
```

If you need to reference other directories, you need to update the arguments above accordingly. Note running `mix phx.digest` will create digested files for all of the assets in `priv/static`, so your images and fonts are still cache-busted.

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

Next, add a custom JavaScript build script. We'll call the example `assets/build.js`:

```js
const esbuild = require('esbuild')

const args = process.argv.slice(2)
const watch = args.includes('--watch')
const deploy = args.includes('--deploy')

const loader = {
  // Add loaders for images/fonts/etc, e.g. { '.svg': 'file' }
}

const plugins = [
  // Add and configure plugins here
]

let opts = {
  entryPoints: ['js/app.js'],
  bundle: true,
  target: 'es2017',
  outdir: '../priv/static/assets',
  logLevel: 'info',
  loader,
  plugins
}

if (watch) {
  opts = {
    ...opts,
    watch,
    sourcemap: 'inline'
  }
}

if (deploy) {
  opts = {
    ...opts,
    minify: true
  }
}

const promise = esbuild.build(opts)

if (watch) {
  promise.then(_result => {
    process.stdin.on('close', () => {
      process.exit(0)
    })

    process.stdin.resume()
  })
}
```

This script covers following use cases:

- `node build.js`: builds for development & testing (useful on CI)
- `node build.js --watch`: like above, but watches for changes continuously
- `node build.js --deploy`: builds minified assets for production

Modify `config/dev.exs` so that the script runs whenever you change files, replacing the existing `:esbuild` configuration under `watchers`:

```elixir
config :hello, HelloWeb.Endpoint,
  ...
  watchers: [
    node: ["build.js", "--watch", cd: Path.expand("../assets", __DIR__)]
  ],
  ...
```

Modify the `aliases` task in `mix.exs` to install `npm` packages during `mix setup` and use the new `esbuild` on `mix assets.deploy`:

```elixir
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      ...,
      "assets.deploy": ["cmd --cd assets node build.js --deploy", "phx.digest"]
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
