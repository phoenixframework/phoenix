# Asset Management

Beside producing HTML, most web applications have various assets (JavaScript, CSS, images, fonts and so on).

From Phoenix v1.7, new applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://github.com/phoenixframework/esbuild), and [tailwindcss](https://tailwindcss.com) via the [Elixir tailwindcss wrapper](https://github.com/phoenixframework/tailwind) for CSS. The direct integration with `esbuild` and `tailwind` means that newly generated applications do not have dependencies on Node.js or an external build system (e.g. Webpack).

Your JavaScript is typically placed at "assets/js/app.js" and `esbuild` will extract it to "priv/static/assets/app.js". In development, this is done automatically via the `esbuild` watcher. In production, this is done by running `mix assets.deploy`.

`esbuild` can also handle your CSS files, but by default `tailwind` handles all CSS building.

Finally, all other assets, that usually don't have to be preprocessed, go directly to "priv/static".

## Third-party JS packages

If you want to import JavaScript dependencies, you have at least three options to add them to your application:

1. Vendor those dependencies inside your project and import them in your "assets/js/app.js" using a relative path:

   ```js
   import topbar from "../vendor/topbar"
   ```

2. Call `npm install topbar --save` inside your assets directory and `esbuild` will be able to automatically pick them up:

   ```js
   import topbar from "topbar"
   ```

3. Use Mix to track the dependency from a source repository:

   ```elixir
   # mix.exs
   {:topbar, github: "buunguyen/topbar", app: false, compile: false}
   ```

   Run `mix deps.get` to fetch the dependency and then import it:

   ```js
   import topbar from "topbar"
   ```

   New applications use this third approach to import Heroicons, avoiding
   vendoring a copy of all icons when you may only use a few or even none,
   avoiding Node.js and `npm`, and tracking an explicit version that is easy to
   update thanks to Mix. It is important to note that git dependencies cannot
   be used by Hex packages, so if you intend to publish your project to Hex,
   consider vendoring the files instead.

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
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const deploy = args.includes('--deploy');

const loader = {
  // Add loaders for images/fonts/etc, e.g. { '.svg': 'file' }
};

const plugins = [
  // Add and configure plugins here
];

// Define esbuild options
let opts = {
  entryPoints: ["js/app.js"],
  bundle: true,
  logLevel: "info",
  target: "es2017",
  outdir: "../priv/static/assets",
  external: ["*.css", "fonts/*", "images/*"],
  nodePaths: ["../deps"],
  loader: loader,
  plugins: plugins,
};

if (deploy) {
  opts = {
    ...opts,
    minify: true,
  };
}

if (watch) {
  opts = {
    ...opts,
    sourcemap: "inline",
  };
  esbuild
    .context(opts)
    .then((ctx) => {
      ctx.watch();
    })
    .catch((_error) => {
      process.exit(1);
    });
} else {
  esbuild.build(opts);
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

## Alternative JS build tools

If you are writing an API or you want to use another asset build tool, you may want to remove the `esbuild` Hex package (see steps below). Then you must follow the additional steps required by the third-party tool.

### Remove esbuild

1. Remove the `esbuild` configuration in `config/config.exs` and `config/dev.exs`,
2. Remove the `assets.deploy` task defined in `mix.exs`,
3. Remove the `esbuild` dependency from `mix.exs`,
4. Unlock the `esbuild` dependency:

```console
$ mix deps.unlock esbuild
```

## Alternative CSS frameworks

By default, Phoenix generates CSS with the `tailwind` library and its default plugins.

If you want to use external `tailwind` plugins or another CSS framework, you should replace the `tailwind` Hex package (see steps below). Then you can use an `esbuild` plugin (as outlined above) or even bring a separate framework altogether.

### Remove tailwind

1. Remove the `tailwind` configuration in `config/config.exs` and `config/dev.exs`,
2. Remove the `assets.deploy` task defined in `mix.exs`,
3. Remove the `tailwind` dependency from `mix.exs`,
4. Unlock the `tailwind` dependency:

```console
$ mix deps.unlock tailwind
```

You may optionally remove and delete the `heroicons` dependency as well.
