  def unique_<%= schema.singular %>_email, do: "<%= schema.singular %>#{System.unique_integer()}@example.com"
  def valid_<%= schema.singular %>_password, do: "hello world!"

  def valid_<%= schema.singular %>_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_<%= schema.singular %>_email(),
      password: valid_<%= schema.singular %>_password()
    })
  end

  def <%= schema.singular %>_fixture(attrs \\ %{}) do
    {:ok, <%= schema.singular %>} =
      attrs
      |> valid_<%= schema.singular %>_attributes()
      |> <%= inspect context.module %>.register_<%= schema.singular %>()

    <%= schema.singular %>
  end

  def extract_<%= schema.singular %>_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
