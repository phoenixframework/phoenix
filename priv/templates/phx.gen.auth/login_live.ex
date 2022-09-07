defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <.header>Log in</.header>

    <.simple_form
      id="login_form"
      :let={f}
      for={:<%= schema.singular %>}
      action={~p"<%= schema.route_prefix %>/log_in"}
      as={:<%= schema.singular %>}
      phx-update="ignore"
    >
      <.input field={{f, :email}} type="email" label="Email" required />
      <.input field={{f, :password}} type="password" label="Password" required />
      <.input field={{f, :remember_me}} type="checkbox" label="Keep me logged in for 60 days" />
      <:actions>
        <.button phx-disable-with="logging in...">Log in</.button>
      </:actions>
    </.simple_form>

    <p>
      <.link href={~p"<%= schema.route_prefix %>/register"}>Register</.link> |
      <.link href={~p"<%= schema.route_prefix %>/reset_password"}>Forgot your password?</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    {:ok, assign(socket, email: email), temporary_assigns: [email: nil]}
  end
end
