defmodule Phoenix.Router.SSLTest do
  use ExUnit.Case, async: false
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options
  alias Phoenix.Router.SSLTest.Router

  setup_all do
    Mix.Config.persist(phoenix: [
      routers: [
        [endpoint: Router,
         port: "71107",
         ssl: true,
         keyfile:  Path.expand("../../fixtures/ssl/key.pem", __DIR__),
         certfile: Path.expand("../../fixtures/ssl/cert.pem", __DIR__)
        ]
      ]
    ])

    defmodule Router do
      use Phoenix.Router
      get "/pages/:page", Pages, :show, as: :page
    end

    :ok
  end

  test "merge port number into options" do
    options = Options.merge([], [], Router, Cowboy)
    assert options[:port] == 71107

    options = Options.merge([], [], Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == true
    assert File.exists? options[:keyfile]
    assert File.exists? options[:certfile]
  end
end

