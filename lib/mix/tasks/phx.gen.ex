defmodule Mix.Tasks.Phx.Gen do
  use Mix.Task

  @shortdoc "Explains in detail what every phx.gen task do"

  @moduledoc """
    ## Explanation of the different types of phoenix generators

    If you're creating an entity, you can decide whether you need to validate it, store it in db, have some helpers in the form of an API boundary (repository helper methods), have an HTML crud, expose a REST JSON API, have a LiveView index/show. depending in which one you need, you may select:
    - `phx.gen.schema` : Generates a db backed entity (includes migration, schema)
    - `phx.gen.embedded` : Generates an schema just for validation (includes schema, no migration)
    - `phx.gen.context` : Generates a context a.k.a. API boundary (includes migration, schema and context )
    - `phx.gen.html` : Generates a HTML CRUD (includes migration, schema, context, controller, view and html CRUD templates)
    - `phx.gen.json` : Generates a REST JSON API (includes migration, schema, context, controller and view)
    - `phx.gen.live` : Generates a LiveView resource (includes migration, schema, live view index/show, live component form/modal and view)

    Other generators:
    - `phx.gen.auth` : Generates authentication logic for a resource.
    - `phx.gen.presence` : Generates a Presence tracker
    - `phx.gen.channel` : Generates a Phoenix channel and its corresponding tests
    - `phx.gen.notifier` : Generates a notifier that delivers emails by default
    - `phx.gen.socket` : Generates a Phoenix socket handler

    Static generators:
    - `phx.gen.cert` : Generates a self-signed certificate for HTTPS testing
    - `phx.gen.secret` : Generates a random key 64 characters long
  """

  def run(_args) do
    Mix.shell.info "If you're generating an entity, you can decide whether you need to validate it, store it in db, have some helpers in the form of an API boundary (repository helper methods), have an HTML crud, expose a REST JSON API, have a LiveView index/show. depending in which one you need, you may select:
    phx.gen.schema : Generates a db backed entity (includes migration, schema)
    phx.gen.embedded : Generates an schema just for validation (includes schema, no migration)
    phx.gen.context : Generates a context a.k.a. API boundary (includes migration, schema and context )
    phx.gen.html : Generates a HTML CRUD (includes migration, schema, context, controller, view and html CRUD templates)
    phx.gen.json : Generates a REST JSON API (includes migration, schema, context, controller and view)
    phx.gen.live : Generates a LiveView resource (includes migration, schema, live view index/show, live component form/modal and view)

    Other generators:
    phx.gen.auth : Generates authentication logic for a resource.
    phx.gen.presence : Generates a Presence tracker
    phx.gen.channel : Generates a Phoenix channel and its corresponding tests
    phx.gen.notifier : Generates a notifier that delivers emails by default
    phx.gen.socket : Generates a Phoenix socket handler

    Static generators:
    phx.gen.cert : Generates a self-signed certificate for HTTPS testing
    phx.gen.secret : Generates a random key 64 characters long
    "
  end
end
