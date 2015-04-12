Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](http://www.phoenixframework.org/docs/up-and-running) to create a basic application to work with.

When preparing an application for deployment, static assets may require special handling. In order to create gzipped digests with a manifest for our static assets, the current Phoenix master branch includes a `phoenix.digest` mix task. (This will be included in the upcoming 0.12.0 release.) This task is designed to be run after `brunch build --production`, or whichever build command is correct for your application.

Now that we've got our application prepared for production, getting it running in a production environment is extremely simple. All we need to do is run this command.

```elixir
MIX_ENV=prod PORT=4001 iex -S mix phoenix.server
```

For guidance on deploying with Erlang style releases, please check out the [Advanced Deployment Guide](http://www.phoenixframework.org/docs/advanced-deployment)

Note, with new Phoenix projects created using Elixir 1.0.4, protocol consolidation happens automatically when we start a Phoenix server with `MIX_ENV=prod`. (Actually, any Phoenix specific mix task will consolidate protocols when invoked with `MIX_ENV=prod`.)

For more information on this, and on running production Elixir applications in general, please see this [Plataformatec Blog entry](http://blog.plataformatec.com.br/2015/04/build-embedded-and-start-permanent-in-elixir-1-0-4/).
