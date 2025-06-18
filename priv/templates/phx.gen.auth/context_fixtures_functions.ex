  import Ecto.Query

  alias <%= inspect context.module %>
  alias <%= inspect scope_config.scope.module %>

  def unique_<%= schema.singular %>_email, do: "<%= schema.singular %>#{System.unique_integer()}@example.com"
  def valid_<%= schema.singular %>_password, do: "hello world!"

  def valid_<%= schema.singular %>_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_<%= schema.singular %>_email()
    })
  end

  def unconfirmed_<%= schema.singular %>_fixture(attrs \\ %{}) do
    {:ok, <%= schema.singular %>} =
      attrs
      |> valid_<%= schema.singular %>_attributes()
      |> <%= inspect context.alias %>.register_<%= schema.singular %>()

    <%= schema.singular %>
  end

  def <%= schema.singular %>_fixture(attrs \\ %{}) do
    <%= schema.singular %> = unconfirmed_<%= schema.singular %>_fixture(attrs)

    token =
      extract_<%= schema.singular %>_token(fn url ->
        <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
      end)

    {:ok, {<%= schema.singular %>, _expired_tokens}} =
      <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(token)

    <%= schema.singular %>
  end

  def <%= schema.singular %>_scope_fixture do
    <%= schema.singular %> = <%= schema.singular %>_fixture()
    <%= schema.singular %>_scope_fixture(<%= schema.singular %>)
  end

  def <%= schema.singular %>_scope_fixture(<%= schema.singular %>) do
    <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>)
  end

  def set_password(<%= schema.singular %>) do
    {:ok, {<%= schema.singular %>, _expired_tokens}} =
      <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, %{password: valid_<%= schema.singular %>_password()})

    <%= schema.singular %>
  end

  def extract_<%= schema.singular %>_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    <%= inspect schema.repo %>.update_all(
      from(t in <%= inspect context.alias %>.<%= inspect schema.alias %>Token,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>) do
    {encoded_token, <%= schema.singular %>_token} = <%= inspect context.alias %>.<%= inspect schema.alias %>Token.build_email_token(<%= schema.singular %>, "login")
    <%= inspect schema.repo %>.insert!(<%= schema.singular %>_token)
    {encoded_token, <%= schema.singular %>_token.token}
  end

  def offset_<%= schema.singular %>_token(token, amount_to_add, unit) do
    dt = <%= inspect datetime_module %>.add(<%= datetime_now %>, amount_to_add, unit)

    <%= inspect schema.repo %>.update_all(
      from(ut in <%= inspect context.alias %>.<%= inspect schema.alias %>Token, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
