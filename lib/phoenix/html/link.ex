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

    * `:form` - customize the underlying form when the method
      is not `:get`

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
      {form, opts} = form_options(opts, method, "link")
      form_tag(to, form) do
        content_tag(:a, text, [href: "#", onclick: "this.parentNode.submit(); return false;"] ++ opts)
      end
    end
  end

  @doc """
  Generates a button that uses a regular HTML form to submit to the given URL.

  Useful to ensure that links that change data are not triggered by
  search engines and other spidering software.

  ## Examples

      button("hello", to: "/world")
      #=> <form action="/world" class="button" method="post">
            <input name="_csrf_token" value=""><input type="submit" value="hello">
          </form>

      button("hello", to: "/world", method: "get", class: "btn")
      #=> <form action="/world" class="btn" method="post">
            <input type="submit" value="hello">
          </form>

  ## Options

    * `:to` - the page to link to. This option is required

    * `:method` - the method to use with the button. Defaults to :post.

    * `:form` - the options for the form. Defaults to
      `[class: "button", enforce_utf8: false]`

  All other options are forwarded to the underlying button input.
  """
  def button(text, opts) do
    {to, opts} = Keyword.pop(opts, :to)
    {method, opts} = Keyword.pop(opts, :method, :post)

    {form, opts} = form_options(opts, method, "button")

    opts =
      opts
      |> Keyword.put_new(:type, "submit")
      |> Keyword.put_new(:value, text)

    unless to do
      raise ArgumentError, "option :to is required in button/2"
    end

    form_tag(to, form) do
      tag(:input, opts)
    end
  end

  defp form_options(opts, method, class) do
    {form, opts} = Keyword.pop(opts, :form, [])

    form =
      form
      |> Keyword.put_new(:class, class)
      |> Keyword.put_new(:method, method)
      |> Keyword.put_new(:enforce_utf8, false)

    {form, opts}
  end
end
