for module <- [RouteFormatter.PageController, RouteFormatter.ImageController] do
  defmodule module do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end
end

defmodule Phoenix.Router.ConsoleFormatterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Router.ConsoleFormatter

  defmodule RouterTestSingleRoutes do
    use Phoenix.Router

    get "/", RouteFormatter.PageController, :index, as: :page
    post "/images", RouteFormatter.ImageController, :upload, as: :upload_image
    delete "/images", RouteFormatter.ImageController, :delete, as: :remove_image
  end

  def __sockets__, do: []

  defmodule FormatterEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/socket", TestSocket, websocket: true
  end

  test "format multiple routes" do
    assert draw(RouterTestSingleRoutes) == """
                   page_path  GET     /        RouteFormatter.PageController :index
           upload_image_path  POST    /images  RouteFormatter.ImageController :upload
           remove_image_path  DELETE  /images  RouteFormatter.ImageController :delete
           """
  end

  defmodule RouterTestResources do
    use Phoenix.Router
    resources "/images", RouteFormatter.ImageController
  end

  test "format resource routes" do
    assert draw(RouterTestResources) == """
           image_path  GET     /images           RouteFormatter.ImageController :index
           image_path  GET     /images/:id/edit  RouteFormatter.ImageController :edit
           image_path  GET     /images/new       RouteFormatter.ImageController :new
           image_path  GET     /images/:id       RouteFormatter.ImageController :show
           image_path  POST    /images           RouteFormatter.ImageController :create
           image_path  PATCH   /images/:id       RouteFormatter.ImageController :update
                       PUT     /images/:id       RouteFormatter.ImageController :update
           image_path  DELETE  /images/:id       RouteFormatter.ImageController :delete
           """
  end

  defmodule RouterTestResource do
    use Phoenix.Router
    resources "/image", RouteFormatter.ImageController, singleton: true
    forward "/admin", RouteFormatter.PageController, [], as: :admin
    forward "/f1", RouteFormatter.ImageController
  end

  test "format single resource routes" do
    assert draw(RouterTestResource) == """
           image_path  GET     /image/edit  RouteFormatter.ImageController :edit
           image_path  GET     /image/new   RouteFormatter.ImageController :new
           image_path  GET     /image       RouteFormatter.ImageController :show
           image_path  POST    /image       RouteFormatter.ImageController :create
           image_path  PATCH   /image       RouteFormatter.ImageController :update
                       PUT     /image       RouteFormatter.ImageController :update
           image_path  DELETE  /image       RouteFormatter.ImageController :delete
                       *       /admin       RouteFormatter.PageController []
                       *       /f1          RouteFormatter.ImageController []
           """
  end

  describe "endpoint sockets" do
    test "format with sockets" do
      assert draw(RouterTestSingleRoutes, FormatterEndpoint) == """
                     page_path  GET     /                  RouteFormatter.PageController :index
             upload_image_path  POST    /images            RouteFormatter.ImageController :upload
             remove_image_path  DELETE  /images            RouteFormatter.ImageController :delete
                                WS      /socket/websocket  TestSocket
                                GET     /socket/longpoll   TestSocket
                                POST    /socket/longpoll   TestSocket
             """
    end

    test "format without sockets" do
      assert draw(RouterTestSingleRoutes, __MODULE__) == """
                     page_path  GET     /        RouteFormatter.PageController :index
             upload_image_path  POST    /images  RouteFormatter.ImageController :upload
             remove_image_path  DELETE  /images  RouteFormatter.ImageController :delete
             """
    end
  end

  defmodule HelpersFalseRouter do
    use Phoenix.Router, helpers: false
    resources "/image", RouteFormatter.ImageController
  end

  test "helpers: false" do
    assert draw(HelpersFalseRouter) == """
             GET     /image           RouteFormatter.ImageController :index
             GET     /image/:id/edit  RouteFormatter.ImageController :edit
             GET     /image/new       RouteFormatter.ImageController :new
             GET     /image/:id       RouteFormatter.ImageController :show
             POST    /image           RouteFormatter.ImageController :create
             PATCH   /image/:id       RouteFormatter.ImageController :update
             PUT     /image/:id       RouteFormatter.ImageController :update
             DELETE  /image/:id       RouteFormatter.ImageController :delete
           """

    assert draw(HelpersFalseRouter, FormatterEndpoint) == """
             GET     /image             RouteFormatter.ImageController :index
             GET     /image/:id/edit    RouteFormatter.ImageController :edit
             GET     /image/new         RouteFormatter.ImageController :new
             GET     /image/:id         RouteFormatter.ImageController :show
             POST    /image             RouteFormatter.ImageController :create
             PATCH   /image/:id         RouteFormatter.ImageController :update
             PUT     /image/:id         RouteFormatter.ImageController :update
             DELETE  /image/:id         RouteFormatter.ImageController :delete
             WS      /socket/websocket  TestSocket
             GET     /socket/longpoll   TestSocket
             POST    /socket/longpoll   TestSocket
           """
  end

  defp draw(router, endpoint \\ nil) do
    ConsoleFormatter.format(router, endpoint)
  end
end
