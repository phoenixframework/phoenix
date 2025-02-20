defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Confirmation do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Welcome {@<%= schema.singular %>.email}</.header>

      <.simple_form
        :if={!@<%= schema.singular %>.confirmed_at}
        for={@form}
        id="confirmation_form"
        phx-submit="submit"
        action={~p"<%= schema.route_prefix %>/log-in?_action=confirmed"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <.input
          :if={!@current_scope.<%= schema.singular %>}
          field={@form[:remember_me]}
          type="checkbox"
          label="Keep me logged in"
        />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <.simple_form
        :if={@<%= schema.singular %>.confirmed_at}
        for={@form}
        id="login_form"
        phx-submit="submit"
        action={~p"<%= schema.route_prefix %>/log-in"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <.input
          :if={!@current_scope.<%= schema.singular %>}
          field={@form[:remember_me]}
          type="checkbox"
          label="Keep me logged in"
        />
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">Log in</.button>
        </:actions>
      </.simple_form>

      <p :if={!@<%= schema.singular %>.confirmed_at} class="mt-8 p-4 border text-center">
        Tip: If you prefer passwords, you can enable them in the <%= schema.singular %> settings.
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "<%= schema.singular %>")

      {:ok, assign(socket, <%= schema.singular %>: <%= schema.singular %>, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"<%= schema.route_prefix %>/log-in")}
    end
  end

  def handle_event("submit", %{"<%= schema.singular %>" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "<%= schema.singular %>"), trigger_submit: true)}
  end
end
