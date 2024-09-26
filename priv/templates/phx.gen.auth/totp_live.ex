defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>TOTPLive do
  use <%= inspect context.web_module %>, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Second step
        <:subtitle>
          Enter the code provided by your 2FA app.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="totp_form"
        action={~p"<%= schema.route_prefix %>/2fa"}
        phx-update="ignore"
      >
        <.input field={@form[:code]} type="text" maxlength="6" label="Code" required />

        <input
          name={@form[:remember_me].name}
          type="hidden"
          id="hidden_remember_me"
          value={@form[:remember_me].value}
        />

        <:actions>
          <.link href={~p"<%= schema.route_prefix %>/log_out"} method="delete" class="text-sm font-semibold">
            Use another account
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, session, socket) do
    if Map.has_key?(session, "unauthenticated_<%= schema.singular %>_id") do
      remember_me = Phoenix.Flash.get(socket.assigns.flash, :remember_me)
      form = to_form(%{"remember_me" => remember_me}, as: "<%= schema.singular %>")

      {:ok, assign(socket, :form, form), temporary_assigns: [form: form]}
    else
      {:ok, push_navigate(socket, to: ~p"<%= schema.route_prefix %>/log_in")}
    end
  end
end
