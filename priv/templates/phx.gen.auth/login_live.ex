defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <h1>Log in</h1>

    <.form
      id="login_form"
      :let={f}
      for={:<%= schema.singular %>}
      action={~p"<%= schema.route_prefix %>/log_in"}
      as={:<%= schema.singular %>}
      phx-update="ignore"
    >
      <%%= label f, :email %>
      <%%= email_input f, :email, required: true, value: @email %>

      <%%= label f, :password %>
      <%%= password_input f, :password, required: true %>

      <%%= label f, :remember_me, "Keep me logged in for 60 days" %>
      <%%= checkbox f, :remember_me %>
      <div>
        <%%= submit "Log in" %>
      </div>
    </.form>

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
