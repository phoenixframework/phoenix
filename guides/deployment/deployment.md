# Introduction to Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](up_and_running.html) to create a basic application to work with.

Our documentation covers three scenarios:

  * Running in production locally - this helps you get your application running in the production environemnt in on your local machine for testing

  * Deploying with releases - package your application into a single directory that you can drop into production using Mix releases

  * Deploying with containers - package your application into a container image using Mix releases

There are also many providers with official documentation for deploying Phoenix applications. We list them below:

  * [Fly.io](https://fly.io/) sponsors Phoenix development and support world-wide clustering. [Use their official guide to deploy your Phoenix application](https://fly.io/docs/elixir/getting-started/).

  * [Render](https://render.com) - deploy with [Mix releases](https://render.com/docs/deploy-phoenix) and set up a [Distributed Elixir Cluster](https://render.com/docs/deploy-elixir-cluster).

  * [Railway](https://railway.com) - deploy with [Mix releases](https://docs.railway.com/guides/phoenix).

  * [Seenode](https://seenode.com) - deploy with [Mix relaeses](https://seenode.com/docs/frameworks/elixir/phoenix/) or try the [quickstart template](https://github.com/seenode/example-phoenix).

We also provide relevant documentation for [clustering](clustering.md).
