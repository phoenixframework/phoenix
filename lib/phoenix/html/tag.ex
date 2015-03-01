defmodule Phoenix.HTML.Tag do
  @moduledoc ~S"""
  Helpers related to producing HTML tags within templates.
  """

  import Phoenix.HTML
  import Phoenix.Controller, only: [get_csrf_token: 0]

  @tag_prefixes [:aria, :data]

  @doc ~S"""
  Creates an HTML tag with the given name and options.

      iex> tag(:br)
      {:safe, "<br>"}
      iex> tag(:input, type: "text", name: "user_id")
      {:safe, "<input name=\"user_id\" type=\"text\">"}
  """
  def tag(name), do: tag(name, [])
  def tag(name, attrs) when is_list(attrs) do
    {:safe, "<#{name}#{build_attrs(name, attrs)}>"}
  end

  @doc ~S"""
  Creates an HTML tag with given name, content, and attributes.

      iex> content_tag(:p, "Hello")
      {:safe, "<p>Hello</p>"}
      iex> content_tag(:p, "<Hello>", class: "test")
      {:safe, "<p class=\"test\">&lt;Hello&gt;</p>"}

      iex> content_tag :p, class: "test" do
      ...>   "Hello"
      ...> end
      {:safe, "<p class=\"test\">Hello</p>"}
  """
  def content_tag(name, content) when is_atom(name) do
    content_tag(name, content, [])
  end

  def content_tag(name, attrs, [do: block]) when is_atom(name) and is_list(attrs) do
    content_tag(name, block, attrs)
  end

  def content_tag(name, content, attrs) when is_atom(name) and is_list(attrs) do
    tag(name, attrs)
    |> safe_concat(content)
    |> safe_concat({:safe, "</#{name}>"})
  end

  defp tag_attrs([]), do: ""
  defp tag_attrs(attrs) do
    for {k, v} <- attrs, into: "" do
      " " <> k <> "=" <> "\"" <> attr_escape(v) <> "\""
    end
  end

  defp attr_escape({:safe, data}),
    do: data
  defp attr_escape(other) when is_binary(other),
    do: Phoenix.HTML.Safe.BitString.to_iodata(other)
  defp attr_escape(other),
    do: Phoenix.HTML.Safe.to_iodata(other)

  defp nested_attrs(attr, dict, acc) do
    Enum.reduce dict, acc, fn {k,v}, acc ->
      attr_name = "#{attr}-#{dasherize(k)}"
      case is_list(v) do
        true  -> nested_attrs(attr_name, v, acc)
        false -> [{attr_name, v}|acc]
      end
    end
  end

  defp build_attrs(_tag, []), do: ""
  defp build_attrs(tag, attrs), do: build_attrs(tag, attrs, [])

  defp build_attrs(_tag, [], acc),
    do: acc |> Enum.sort |> tag_attrs
  defp build_attrs(tag, [{k, v}|t], acc) when k in @tag_prefixes and is_list(v) do
    build_attrs(tag, t, nested_attrs(dasherize(k), v, acc))
  end
  defp build_attrs(tag, [{k, true}|t], acc) do
    k = dasherize(k)
    build_attrs(tag, t, [{k, k}|acc])
  end
  defp build_attrs(tag, [{k, v}|t], acc) do
    build_attrs(tag, t, [{dasherize(k), v}|acc])
  end

  defp dasherize(value) when is_atom(value),   do: dasherize(Atom.to_string(value))
  defp dasherize(value) when is_binary(value), do: String.replace(value, "_", "-")

  @doc ~S"""
  Generates a form tag.

  This function generates the `<form>` tag without its
  closing part.

  ## Options

    * `:method` - the HTTP method. If the method is not "get" nor "post",
      an input tag with name `_method` is generated along-side the form tag

    * `:multipart` - when true, sets enctype to "multipart/form-data".
      Required when uploading files

    * `:csrf_token` - for "post" requests, the form tag will automatically
      include an input tag with name `_csrf_token`. When set to false, this
      is disabled

    * `:enforce_utf8` - when false, does not enforce utf8. Read below
      for more information

  All other options are passed to the underlying HTML tag.

  ## Enforce UTF-8

  Alhought forms provide the `accept-charset` attribute, which we set
  to UTF-8, Internet Explorer 5 up to 8 may ignore the value of this
  attribute if the user chooses their browser to do so. This ends up
  triggering the browser to send data in a format that is not
  understandable by the server.

  For this reason, Phoenix automatically includes a "_utf8=✓" parameter
  in your forms, to force those browsers to send the data in the proper
  encoding. This technique has been seen in the Rails web framework and
  reproduced here.
  """
  def form_tag(opts \\ []) do
    {:safe, method} = html_escape(Keyword.get(opts, :method, "get"))

    {opts, extra} =
      case method do
        "get"  -> {opts, ""}
        "post" -> csrf_token_tag(opts, "")
        _      -> csrf_token_tag(Keyword.put(opts, :method, "post"),
                                 ~s'<input name="_method" type="hidden" value="#{method}">')
      end

    {opts, extra} =
      case Keyword.pop(opts, :enforce_utf8, true) do
        {false, opts} -> {opts, extra}
        {true, opts}  -> {Keyword.put_new(opts, :accept_charset, "UTF-8"),
                          extra <> ~s'<input name="_utf8" type="hidden" value="✓">'}
      end

    opts =
      case Keyword.pop(opts, :multipart, false) do
        {false, opts} -> opts
        {true, opts}  -> Keyword.put(opts, :enctype, "multipart/form-data")
      end

    safe_concat tag(:form, opts), safe(extra)
  end

  defp csrf_token_tag(opts, extra) do
    case Keyword.pop(opts, :csrf_token, true) do
      {true, opts} ->
        {opts, extra <> ~s'<input name="_csrf_token" type="hidden" value="#{get_csrf_token}">'}
      {false, opts} ->
        {opts, extra}
    end
  end
end
