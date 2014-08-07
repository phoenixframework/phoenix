defmodule Phoenix.Router.RouteAlias do
  alias Phoenix.Router.RouteAlias
  alias Phoenix.Router.Path

  # GET       /posts             posts_path()
  # GET       /posts/new         posts_path(:new)
  # POST      /posts             posts_path()
  # GET       /posts/:id         posts_path(id: 123)
  # GET       /posts/:id/edit    posts_path(:edit, id: 123)
  # PATCH/PUT /posts/:id         posts_path(id: 123)
  # DELETE    /posts/:id         posts_path(id: 123)

  def defalias(alias_name, path, action, module) do
    Module.register_attribute(module, :route_aliases, accumulate: true, persist: false)
    aliases = Module.get_attribute(module, :route_aliases)

    unless Enum.member?(aliases, {alias_name, action}) do
      defalias(alias_name, path, action)
    end
  end

  def defalias(alias_name, path, action) do
    quote do
      @route_aliases {unquote(alias_name), unquote(action)}
      def unquote(:"#{alias_name}_path")(unquote(action), id, params) do
        Path.build(unquote(path), Dict.merge(params, id: id))
      end
      def unquote(:"#{alias_name}_path")(unquote(action), {key, val}, params) do
        Path.build(unquote(path), Dict.put(params, key, val))
      end
      def unquote(:"#{alias_name}_url")(unquote(action), id, params) do
        RouteAlias.build_url(unquote(path), params, __MODULE__)
      end
      def unquote(:"#{alias_name}_url")(unquote(action), {key, val}, params) do
        RouteAlias.build_url(unquote(path), Dict.put(params, key, val), __MODULE__)
      end
    end
  end

  def defalias(alias_name, path, :edit) do
    quote do
      @route_aliases {unquote(alias_name), :edit}
      def unquote(:"#{alias_name}_path")(:edit, id, params) do
        Path.build(unquote(path), Dict.merge(params, id: id))
      end
      def unquote(:"#{alias_name}_path")(:edit, {key, val}, params) do
        Path.build(unquote(path), Dict.put(params, key, val))
      end
      def unquote(:"#{alias_name}_url")(:edit, id, params) do
        RouteAlias.build_url(unquote(path), params, __MODULE__)
      end
      def unquote(:"#{alias_name}_url")(:edit, {key, val}, params) do
        RouteAlias.build_url(unquote(path), Dict.put(params, key, val), __MODULE__)
      end
    end
  end

  def defalias(alias_name, path, :index) do
    quote do
      @route_aliases {unquote(alias_name), :index}
      def unquote(:"#{alias_name}_path")(params \\ []) do
        Path.build(unquote(path), params)
      end
      def unquote(:"#{alias_name}_url")(params \\ []) do
        RouteAlias.build_url(unquote(path), params, __MODULE__)
      end
    end
  end

  def build_url(path_string, params, module) do
    path_string
    |> Path.build(params)
    |> Path.build_url(ssl:  Config.router(module, [:ssl]),
                      host: Config.router(module, [:host]),
                      port: Config.router(module, [:proxy_port]) ||
                            Config.router(module, [:port]))
  end
end
