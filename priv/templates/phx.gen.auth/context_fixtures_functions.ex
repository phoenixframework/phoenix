
  def unique_<%= schema.singular %>_email, do: "<%= schema.singular %>#{System.unique_integer()}@example.com"
  def valid_<%= schema.singular %>_password, do: "hello world!"

  def <%= schema.singular %>_fixture(attrs \\ %{}) do
    {:ok, <%= schema.singular %>} =
      attrs
      |> Enum.into(%{
        email: unique_<%= schema.singular %>_email(),
        password: valid_<%= schema.singular %>_password()
      })
      |> <%= inspect context.module %>.register_<%= schema.singular %>()

    <%= schema.singular %>
  end

  def extract_<%= schema.singular %>_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end
