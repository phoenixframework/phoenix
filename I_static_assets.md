### Static Assets

Static assets are enabled by default and served from the `priv/static/`
directory of your application. The assets are mounted at the root path, so
`priv/static/js/phoenix.js` would be served from `example.com/js/phoenix.js`.
See configuration options for details on disabling assets and customizing the
mount point.

#### Precompilers

You can add any kind of asset precompiler to your workflow with
[Rotor](https://github.com/hashnuke/rotor). Rotor is a build system for elixir
projects and it already has some useful extensions:

* [Sass](https://github.com/danielfarrell/sass_rotor)
* [CoffeeScript](https://github.com/HashNuke/coffee_rotor)

You can integrate it with your phoenix application, for example, by adding an
`initializers.ex` file to your `lib` directory that has the configurations for
your rotors.

Here's an example for the Sass rotor:

``` elixir
import Rotor.BasicRotors
import SassRotor


defmodule AppName.Initializers do
  def start_rotors do
    output_path = "priv/static/assets/application.css"
    Rotor.watch :stylesheets, ["priv/assets/stylesheets/*.sass"], fn(_changed_files, all_files)->
      read_files(all_files)
      |> sass
      |> concat
      |> output_to(output_path)
    end
  end
end
```

Then you have to make sure the rotors are started at the same time of the
application, by calling `start_rotors` from your `lib/app_name.ex` file.

``` elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false

  children = [
    worker(Repo, [])
  ]

  # we start rotors only in development
  if Mix.env == :dev do
    AppName.Initializers.start_rotors
  end

  opts = [strategy: :one_for_one, name: AppName.Supervisor]
  Supervisor.start_link(children, opts)
end
```

*Note:* The Sass rotor ultimately depends on libsass, and thus does not support
the `--compass` option. Until there is any support for that, you'll need to use
any other way for precompiling the files, but as long as it is compiled into the
`priv/static/assets` directory everything should work fine.
