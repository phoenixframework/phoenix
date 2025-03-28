defmodule <%= @web_namespace %>.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use <%= @web_namespace %>, :html

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li><%= if @css do %>
          <li>
            <.theme_switcher />
          </li><% end %>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title=<%= maybe_heex_attr_gettext.("We can't find the internet", @gettext) %>
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        <%= maybe_eex_gettext.("Attempting to reconnect", @gettext) %>
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title=<%= maybe_heex_attr_gettext.("Something went wrong!", @gettext) %>
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        <%= maybe_eex_gettext.("Hang in there while we get back on track", @gettext) %>
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  # Example daisyUI theme switcher, powered by a theme switcher script
  # included in layouts/root.html.heex.
  def theme_switcher(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn">
        Theme
        <span aria-hidden="true" class="text-xs font-normal">
          <.icon class="size-4" name="hero-chevron-down-micro" />
        </span>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 flex flex-row rounded-field z-1 w-52 mt-2 shadow-sm h-64 overflow-y-scroll"
      >
        <li
          :for={
            theme <-
              ~w(system light dark abyss acid aqua autumn black bumblebee business caramellatte cmyk coffee) ++
                ~w(corporate cupcake cyberpunk dark dim dracula emerald fantasy forest garden halloween) ++
                ~w(lemonade lofi luxury night nord pastel retro silk sunset synthwave valentine winter wireframe)
          }
          class="w-full"
        >
          <a class="capitalize" phx-click={JS.dispatch("phx:set-theme", detail: %{theme: theme})}>
            {theme}
          </a>
        </li>
      </ul>
    </div>
    """
  end
end
