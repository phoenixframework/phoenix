  import <%= inspect context.module %>Fixtures
  alias <%= inspect context.module %>.{<%= inspect schema.alias %>, <%= inspect schema.alias %>Token}

  describe "get_<%= schema.singular %>_by_email/1" do
    test "does not return the <%= schema.singular %> if the email does not exist" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email("unknown@example.com")
    end

    test "returns the <%= schema.singular %> if the email exists" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert %<%= inspect schema.alias %>{id: ^id} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(<%= schema.singular %>.email)
    end
  end

  describe "get_<%= schema.singular %>_by_email_and_password/2" do
    test "does not return the <%= schema.singular %> if the email does not exist" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the <%= schema.singular %> if the password is not valid" do
      <%= schema.singular %> = <%= schema.singular %>_fixture() |> set_password()
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "invalid")
    end

    test "returns the <%= schema.singular %> if the email and password are valid" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture() |> set_password()

      assert %<%= inspect schema.alias %>{id: ^id} =
               <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, valid_<%= schema.singular %>_password())
    end
  end

  describe "get_<%= schema.singular %>!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= inspect schema.sample_id %>)
      end
    end

    test "returns the <%= schema.singular %> with the given id" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert %<%= inspect schema.alias %>{id: ^id} = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%=schema.singular %>.id)
    end
  end

  describe "register_<%= schema.singular %>/1" do
    test "requires email to be set" do
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = <%= schema.singular %>_fixture()
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers <%= schema.plural %> without password" do
      email = unique_<%= schema.singular %>_email()
      {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.register_<%= schema.singular %>(valid_<%= schema.singular %>_attributes(email: email))
      assert <%= schema.singular %>.email == email
      assert is_nil(<%= schema.singular %>.hashed_password)
      assert is_nil(<%= schema.singular %>.confirmed_at)
      assert is_nil(<%= schema.singular %>.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = <%= inspect datetime_module %>.utc_now()

      assert <%= inspect context.alias %>.sudo_mode?(%<%= inspect schema.alias %>{authenticated_at: <%= inspect datetime_module %>.utc_now()})
      assert <%= inspect context.alias %>.sudo_mode?(%<%= inspect schema.alias %>{authenticated_at: <%= inspect datetime_module %>.add(now, -19, :minute)})
      refute <%= inspect context.alias %>.sudo_mode?(%<%= inspect schema.alias %>{authenticated_at: <%= inspect datetime_module %>.add(now, -21, :minute)})

      # minute override
      refute <%= inspect context.alias %>.sudo_mode?(
               %<%= inspect schema.alias %>{authenticated_at: <%= inspect datetime_module %>.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute <%= inspect context.alias %>.sudo_mode?(%<%= inspect schema.alias %>{})
    end
  end

  describe "change_<%= schema.singular %>_email/3" do
    test "returns a <%= schema.singular %> changeset" do
      assert %Ecto.Changeset{} = changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_<%= schema.singular %>_update_email_instructions/3" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends token through notification", %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(<%= schema.singular %>, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: :crypto.hash(:sha256, token))
      assert <%= schema.singular %>_token.<%= schema.singular %>_id == <%= schema.singular %>.id
      assert <%= schema.singular %>_token.sent_to == <%= schema.singular %>.email
      assert <%= schema.singular %>_token.context == "change:current@example.com"
    end
  end

  describe "update_<%= schema.singular %>_email/2" do
    setup do
      <%= schema.singular %> = unconfirmed_<%= schema.singular %>_fixture()
      email = unique_<%= schema.singular %>_email()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(%{<%= schema.singular %> | email: email}, <%= schema.singular %>.email, url)
        end)

      %{<%= schema.singular %>: <%= schema.singular %>, token: token, email: email}
    end

    test "updates the email with a valid token", %{<%= schema.singular %>: <%= schema.singular %>, token: token, email: email} do
      assert {:ok, %{email: ^email}} = <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, token)
      changed_<%= schema.singular %> = Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id)
      assert changed_<%= schema.singular %>.email != <%= schema.singular %>.email
      assert changed_<%= schema.singular %>.email == email
      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email with invalid token", %{<%= schema.singular %>: <%= schema.singular %>} do
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email if <%= schema.singular %> email changed", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(%{<%= schema.singular %> | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email if token expired", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "change_<%= schema.singular %>_password/3" do
    test "returns a <%= schema.singular %> changeset" do
      assert %Ecto.Changeset{} = changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(%<%= inspect schema.alias %>{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        <%= inspect context.alias %>.change_<%= schema.singular %>_password(
          %<%= inspect schema.alias %>{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_<%= schema.singular %>_password/2" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "validates password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{<%= schema.singular %>: <%= schema.singular %>} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:ok, {<%= schema.singular %>, expired_tokens}} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(<%= schema.singular %>.password)
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "new valid password")
    end

    test "deletes all tokens for the given <%= schema.singular %>", %{<%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

      {:ok, {_, _}} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, %{
          password: "new valid password"
        })

      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "generate_<%= schema.singular %>_session_token/1" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "generates a token", %{<%= schema.singular %>: <%= schema.singular %>} do
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: token)
      assert <%= schema.singular %>_token.context == "session"
      assert <%= schema.singular %>_token.authenticated_at != nil

      # Creating the same token for another <%= schema.singular %> should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%<%= inspect schema.alias %>Token{
          token: <%= schema.singular %>_token.token,
          <%= schema.singular %>_id: <%= schema.singular %>_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given <%= schema.singular %> in new token", %{<%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %> = %{<%= schema.singular %> | authenticated_at: <%= inspect datetime_module %>.add(<%= datetime_now %>, -3600)}
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: token)
      assert <%= schema.singular %>_token.authenticated_at == <%= schema.singular %>.authenticated_at
      assert <%= inspect datetime_module %>.compare(<%= schema.singular %>_token.inserted_at, <%= schema.singular %>.authenticated_at) == :gt
    end
  end

  describe "get_<%= schema.singular %>_by_session_token/1" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      %{<%= schema.singular %>: <%= schema.singular %>, token: token}
    end

    test "returns <%= schema.singular %> by token", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert {session_<%= schema.singular %>, token_inserted_at} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
      assert session_<%= schema.singular %>.id == <%= schema.singular %>.id
      assert session_<%= schema.singular %>.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return <%= schema.singular %> for invalid token" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token("oops")
    end

    test "does not return <%= schema.singular %> for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: dt, authenticated_at: dt])
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end
  end

  describe "get_<%= schema.singular %>_by_magic_link_token/1" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      {encoded_token, _hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)
      %{<%= schema.singular %>: <%= schema.singular %>, token: encoded_token}
    end

    test "returns <%= schema.singular %> by token", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert session_<%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token(token)
      assert session_<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "does not return <%= schema.singular %> for invalid token" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token("oops")
    end

    test "does not return <%= schema.singular %> for expired token", %{token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token(token)
    end
  end

  describe "login_<%= schema.singular %>_by_magic_link/1" do
    test "confirms <%= schema.singular %> and expires tokens" do
      <%= schema.singular %> = unconfirmed_<%= schema.singular %>_fixture()
      refute <%= schema.singular %>.confirmed_at
      {encoded_token, hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)

      assert {:ok, {<%= schema.singular %>, [%{token: ^hashed_token}]}} =
               <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(encoded_token)

      assert <%= schema.singular %>.confirmed_at
    end

    test "returns <%= schema.singular %> and (deleted) token for confirmed <%= schema.singular %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert <%= schema.singular %>.confirmed_at
      {encoded_token, _hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)
      assert {:ok, {^<%= schema.singular %>, []}} = <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed <%= schema.singular %> has password set" do
      <%= schema.singular %> = unconfirmed_<%= schema.singular %>_fixture()
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_<%= schema.singular %>_session_token/1" do
    test "deletes the token" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      assert <%= inspect context.alias %>.delete_<%= schema.singular %>_session_token(token) == :ok
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{<%= schema.singular %>: unconfirmed_<%= schema.singular %>_fixture()}
    end

    test "sends token through notification", %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: :crypto.hash(:sha256, token))
      assert <%= schema.singular %>_token.<%= schema.singular %>_id == <%= schema.singular %>.id
      assert <%= schema.singular %>_token.sent_to == <%= schema.singular %>.email
      assert <%= schema.singular %>_token.context == "login"
    end
  end

  describe "inspect/2 for the <%= inspect schema.alias %> module" do
    test "does not include password" do
      refute inspect(%<%= inspect schema.alias %>{password: "123456"}) =~ "password: \"123456\""
    end
  end
