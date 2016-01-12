Since our Phoenix apps are simply Elixir applications, they  have the same configuration and structure as other Mix projects. Recall that Mix is the build tool used by most Elixir apps.

#### .ex and .exs Files Types

The config for our Phoenix app is stored in a combination of `.ex` and `.exs` files. Although both file types are Elixir scripts, they are compiled differently.

Our `.exs` files are compiled in memory each time they are run (such as on reload), which makes them ideal for storing configuration details and scripts that change often (such as standalone tasks during development).

Whereas `.ex` files are compiled to `.beam` files that run on the Erlang Virtual Machine (BEAM), which makes them useful for storing higher level configuration that changes less frequently (such as endpoint and OTP supervisor/worker config). 


#### Config Files and Environments

Our `mix.exs` config file is located in the root folder of our app and contains some important overall config details relating to our app, including compilation paths, dependencies and aliases.

Phoenix applications are intended to be run with configuration particular to different environments, such as 'development' or 'production'. This allows for an improved developer experience and smoother workflow when deploying apps to production. By default, the `/config` folder at the root of our app will include the following config files:

`config.exs`, which is our master config file that is common across all our environments. It contains overall app config such as our logging and endpoint details, such as our app url and root directory. Additionally, towards the bottom of this file, we also take the important step of importing the configuration specific to our current environment.  We can easily switch between the different configuration files for our environments by adjusting the value for the `Mix.env` environment variable below when we start/deploy our app; for instance, we'd set the value to `"#prod.exs"` for our production environment.

```elixir
...
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
...
```

`dev.exs`, which is used to store config details specific to our development environment, such as debugging settings and our database connection details.

`prod.exs`, which is used to store config for our production environment, since these settings often need to be different and more strict than our dev or test environments. For instance, in production we use stronger hashing of passwords, which would slow down performance during development or testing, but is an unavoidable expense for a production app.

`prod.secret.exs`, which is used to store sensitive configuration details relating to our production environment (such as passwords or API keys), and is thus generally excluded from the version control in our code repository.  Note that config details from this file can be imported into our other files as appropriate.

`test.exs`, which is used to store any config details specific to our testing environment.

We should open each of these files and familiarize ourselves with the contents. 

In addition to these default development (`dev.exs`), test (`test.exs`) and production (`prod.exs`) environment configurations, Phoenix supports the use of custom environment configurations that we can manually add as we get more advanced.

#### Umbrella Apps

Umbrella apps enable multiple child applications to run together, which can help to reduce the overall complexity of our app by separating different functionality into smaller apps that run together. While a full discussion of Umbrella Apps extends beyond the scope of this Guide, for now it's worth simply noting that the configuration of an Umbrella app is slightly different (and in some ways a bit simpler) than what's outlined above, since much of the configuration details will reside in the config for each of the children apps.

#### Summary

Config is an important topic and essential to every app we build. The important points to take away from this guide are that:
- Our `.ex` and `.exs` files are used to store the configuration for our app.
- Our `.exs` files are compiled in memory each time they are run which makes them ideal for storing configuration details.
- Mix apps include config for development, test and production environments by default, and custom environments can be manually added.
- We can store our sensitive production config in our `prod.secret.exs` file, outside of version control.
