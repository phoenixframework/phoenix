defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Sign in to account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"<%= schema.route_prefix %>/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for an account now.
        </:subtitle>
      </.header>

      <.simple_form
        :let={f}
        id="login_form"
        for={:<%= schema.singular %>}
        action={~p"<%= schema.route_prefix %>/log_in"}
        as={:<%= schema.singular %>}
        phx-update="ignore"
      >
        <.input field={{f, :email}} type="email" label="Email" required />
        <.input field={{f, :password}} type="password" label="Password" required />

        <:actions :let={f}>
          <.input field={{f, :remember_me}} type="checkbox" label="Keep me logged in" />
          <.link href={~p"<%= schema.route_prefix %>/reset_password"} class="text-sm font-semibold">
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Sigining in..." class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    {:ok, assign(socket, email: email), temporary_assigns: [email: nil]}
  end
end
