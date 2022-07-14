defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <h1>Log in</h1>

    <.form
      id="login_form"
      :let={f}
      for={:<%= schema.singular %>}
      action={Routes.<%= schema.route_helper %>_session_path(@socket, :create)}
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
      <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
      <.link href={Routes.<%= schema.route_helper %>_forgot_password_path(@socket, :new)}>Forgot your password?</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    {:ok, assign(socket, email: email), temporary_assigns: [email: nil]}
  end
end
