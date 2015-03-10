defmodule Phoenix.HTML.Link do
  @moduledoc """
  Conveniences for working with links and URLs in HTML.
  """

  import Phoenix.HTML.Tag

  @doc """
  Generates a link to the given URL.

  ## Examples

      iex> link("hello", to: "/world")
      {:safe, ~s(<a href="/world">hello</a>)}

      iex> link("<hello>", to: "/world")
      {:safe, ~s(<a href="/world">&lt;hello&gt;</a>)}

      iex> link("<hello>", to: "/world", class: "btn")
      {:safe, ~s(<a class="btn" href="/world">&lt;hello&gt;</a>)}

  ## Options

    * `:to` - the page to link to. This option is required

    * `:method` - the method to use with the link. In case the
      method is not `:get`, the link is generated inside the form
      which sets the proper information. In order to submit the
      form, JavaScript must be enabled

  All other options are forwarded to the underlying `<a>` tag.
  """
  def link(text, opts) do
    {to, opts} = Keyword.pop(opts, :to)
    {method, opts} = Keyword.pop(opts, :method, :get)

    unless to do
      raise ArgumentError, "option :to is required in link/2"
    end

    if method == :get do
      content_tag(:a, text, [href: to] ++ opts)
    else
      form_tag(to, method: method, class: "linkmethod", enforce_utf8: false) do
        content_tag(:a, text, [href: "#", onclick: "this.parentNode.submit(); return false;"] ++ opts)
      end
    end
  end

  @doc """
  Generates a button that uses a regular HTML form to submit to the given URL.
  Useful to ensure that links that change data are not triggered by
  search engines and other spidering software.

  ## Examples

      <%= button("hello", to: "/world") %>

  generates

      <form action="/world" class="button" method="post">
        <input name="_csrf_token" value=""><input type="submit" value="hello">
      </form>

  ## Options

    * `:to` - the page to link to. This option is required

    * `:method` - the method to use with the link. Defaults to :post.

  """
  def button(text, opts) do
    {to, opts} = Keyword.pop(opts, :to)
    {method, opts} = Keyword.pop(opts, :method, :post)
    {htmlClass, opts} = Keyword.pop(opts, :class, :button)

    unless to do
      raise ArgumentError, "option :to is required in button/2"
    end

    form_tag(to, [method: method, class: htmlClass, enforce_utf8: false] ++ opts) do
      tag(:input, [type: "submit", value: text])
    end
  end
end
