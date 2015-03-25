Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](http://www.phoenixframework.org/docs/up-and-running) to create a basic application to work with.

Getting your phoenix application running in a production environment is extremely simple all that you need to do is

```elixir
MIX_ENV=prod mix compile.protocols
MIX_ENV=prod PORT=4001 elixir -pa _build/prod/consolidated -S mix phoenix.server
```

And you are up and running. If you find yourself needing guidance for a more advanced release procedure please check out [Advanced Deployment](http://www.phoenixframework.org/docs/advanced-deployment)
