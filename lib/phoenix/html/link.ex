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
        content_tag(:a, text, [onclick: "this.parentNode.submit()"] ++ opts)
      end
    end
  end
end
