# API Authentication

> **Requirement**: This guide expects that you have gone through the [`mix phx.gen.auth`](mix_phx_gen_auth.html) guide.

This guide shows how to add API authentication on top of `mix phx.gen.auth`. Since the authentication generator already includes a token table, we use it to store API tokens too, following the best security practices.

We will break this guide in two parts: augmenting the context and the plug implementation. We will assume that the following `mix phx.gen.auth` command was executed:

```
$ mix phx.gen.auth Accounts User users
```

If you ran something else, it should be trivial to adapt the names.

## Adding API functions to the context

Our authentication system will require two functions. One to create the API token and another to verify it. Open up `lib/my_app/accounts.ex` and add these two new functions:

```elixir
  ## API

  @doc """
  Creates a new api token for a user.

  The token returned must be saved somewhere safe.
  This token cannot be recovered from the database.
  """
  def create_user_api_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "api-token")
    Repo.insert!(user_token)
    encoded_token
  end

  @doc """
  Fetches the user by API token.
  """
  def fetch_user_by_api_token(token) do
    with {:ok, query} <- UserToken.verify_api_token_query(token),
         %User{} = user <- Repo.one(query) do
      {:ok, user}
    else
      _ -> :error
    end
  end
```

The new functions use the existing `UserToken` functionality to store a new type of token called "api-token". Because this is an email token, if the user changes their email, the tokens will be expired.

Also notice we called the second function `fetch_user_by_api_token`, instead of `get_user_by_api_token`. Because we want to render different status codes in our API, depending if a user was found or not, we return `{:ok, user}` or `:error`. Elixir's convention is to call these functions `fetch_*`, instead of `get_*` which would usually return `nil` instead of tuples.

To make sure our new functions work, let's write tests. Open up `test/my_app/accounts_test.exs` and add this new describe block:

```elixir
  describe "create_user_api_token/1 and fetch_user_by_api_token/1" do
    test "creates and fetches by token" do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)
      assert Accounts.fetch_user_by_api_token(token) == {:ok, user}
      assert Accounts.fetch_user_by_api_token("invalid") == :error
    end
  end
```

If you run the tests, they will actually fail. Something similar to this:

```console
1) test create_user_api_token/1 and fetch_user_by_api_token/1 creates and fetches by token (Demo.AccountsTest)
    test/demo/accounts_test.exs:380
    ** (UndefinedFunctionError) function Demo.Accounts.UserToken.verify_api_token_query/1 is undefined or private. Did you mean:

          * verify_change_email_token_query/2
          * verify_magic_link_token_query/1
          * verify_session_token_query/1
    
    code: assert Accounts.fetch_user_by_api_token(token) == {:ok, user}
    stacktrace:
      (demo 0.1.0) Demo.Accounts.UserToken.verify_api_token_query("sTpJg7rt-KQ9gZ7xLMtn2keusGk9N2JpPwkXDx7LmHU")
      (demo 0.1.0) lib/demo/accounts.ex:325: Demo.Accounts.fetch_user_by_api_token/1
      test/demo/accounts_test.exs:383: (test)
```

If you prefer, try looking at the error and fixing it yourself. The explanation will come next.

The `UserToken` module contains functions for verifying different tokens. Right now, there is no `verify_api_token_query/1`, but we can implement it similar to the existing functions. How long the API token should be valid is going to depend on your application and how sensitive it is in terms of security. For this example, let's say the token is valid for 365 days.

Open up `lib/my_app/accounts/user_token.ex`, and add a new function, like this:

```elixir
  @doc """
  Checks if the API token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database and the user email has not changed. This function also checks
  if the token is being used within 365 days.
  """
  def verify_api_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "api-token"),
            join: user in assoc(token, :user),
            where:
              token.inserted_at > ago(^@api_token_validity_in_days, "day") and
                token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end
```

Note that we also added a `@api_token_validity_in_days` module attribute at the top of the file:

```diff
   @magic_link_validity_in_minutes 15
   @change_email_validity_in_days 7
   @session_validity_in_days 60
+  @api_token_validity_in_days 365
```

Now tests should pass and we are ready to move forward!

## API authentication plug

The last part is to add authentication to our API.

When we ran `mix phx.gen.auth`, it generated a `MyAppWeb.UserAuth` module with several plugs, which are small functions that receive the `conn` and customize our request/response life-cycle. Open up `lib/my_app_web/user_auth.ex` and add this new function:

```elixir
def fetch_current_scope_for_api_user(conn, _opts) do
  with [<<bearer::binary-size(6), " ", token::binary>>] <-
         get_req_header(conn, "authorization"),
       true <- String.downcase(bearer) == "bearer",
       {:ok, user} <- Accounts.fetch_user_by_api_token(token) do
    assign(conn, :current_scope, Scope.for_user(user))
  else
    _ ->
      conn
      |> send_resp(:unauthorized, "No access for you")
      |> halt()
  end
end
```

Our function receives the connection and checks if the "authorization" header has been set with "Bearer TOKEN", where "TOKEN" is the value returned by `Accounts.create_user_api_token/1`. In case the token is not valid or there is no such user, we abort the request.

Finally, we need to add this `plug` to our pipeline. Open up `lib/my_app_web/router.ex` and you will find a pipeline for API. Let's add our new plug under it, like this:

```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_scope_for_api_user
  end
```

Now you are ready to receive and validate API requests. Feel free to open up `test/my_app_web/user_auth_test.exs` and write your own test. You can use the tests for other plugs as templates!

## Your turn

The overall API authentication flow will depend on your application.

If you want to use this token in a JavaScript client, you will need to slightly alter the `UserSessionController` to invoke `Accounts.create_user_api_token/1` and return a JSON response including the token.

If you want to provide APIs for 3rd-party users, you will need to allow them to create tokens, and show the result of `Accounts.create_user_api_token/1` to them. They must save these tokens somewhere safe and include them as part of their requests using the "authorization" header.
