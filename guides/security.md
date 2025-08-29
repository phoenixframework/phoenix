# Security 

All software exposed to the public internet will be attacked. Most Phoenix applications fall into this category, so it is useful to understand common types of web application security vulnerabilities, the impact of each, and how to avoid them. Consider the following scenario:

You are responsible for a banking application which handles transactions via a Phoenix backend. A new code change introduces a remote code execution (RCE) vulnerability, granting an attacker production SSH access to the server. This results in the database being exfiltrated, user accounts being compromised, and customer funds being stolen. 

With the rise of generative AI coding tools, proper judgement on the security of code has become more important than ever. This document will detail how severe vulnerabilities can occur in a Phoenix project and secure coding best practices to help avoid an incident.  

## Remote Code Execution (RCE)

A remote code execution (RCE) vulnerability grants an attacker the equivalent of production SSH access to your web server. This type of vulnerability is often considered the worst possible case, because it does not require user interaction and allows an attacker to bypass all security controls in your application.

You should never pass untrusted user input to the following functions:

```
# Code functions
Code.eval_string/3
Code.eval_file/2
Code.eval_quoted/3

# EEX functions
eval_string/3
eval_file/3

# Command injection functions
:os.cmd/2
System.cmd/3
System.shell/2
```

All of these functions execute arbitrary code on your server if passed external input. The risk here is obvious to most programmers, so it is rare to find a Phoenix application vulnerable in this way. 

The more common and often unexpected way a Phoenix application is vulnerable to RCE is via the Erlang function `binary_to_term`. From [the Erlang docs:](https://www.erlang.org/doc/apps/erts/erlang.html#binary_to_term/2)

> When decoding binaries from untrusted sources, the untrusted source may submit data in a way to create resources, such as atoms and remote references, that cannot be garbage collected and lead to a Denial of Service (DoS) attack. In such cases, use `binary_to_term/2` with the `safe` option.

This warning is confusing, because the `safe` option mentioned above only prevents the creation of new atoms at runtime. It does not prevent the creation of executable terms via malicious user input, which is a much greater risk. 

```
# Not safe
:erlang.binary_to_term(user_input, [:safe])

# Safe
Plug.Crypto.non_executable_binary_to_term(user_input, [:safe])
```

The function `Plug.Crypto.non_executable_binary_to_term` prevents the creation of executable terms at runtime. If you are curious how this vulnerability can occur in the real world, see the writeup on [CVE-2020-15150 in the library Paginator.](https://www.alphabot.com/security/blog/2020/elixir/Remote-code-execution-vulnerability-in-Elixir-based-Paginator-project.html)


## SQL Injection 

SQL injection is on par with RCE as a highly severe vulnerability that leads to your entire database being leaked, and can even be leveraged to achieve code execution in some contexts. The good news for Phoenix developers is the majority of applications use Ecto, which is the interface to a dedicated database, typically PostgreSQL or MySQL. The Ecto query syntax protects against SQL injection by default:

```
# Safe, using query syntax 
def a_get_fruit(min_q) do
  from(
    f in Fruit,
    where:
      f.quantity >= ^min_q and
        f.secret == false
  )
  |> Repo.all()
end
```

The `fragment` function seems to be a vector for SQL injection:

```
# Fails to compile 
def b_get_fruit(min_q) do
  from(
    f in Fruit,
    where: fragment("f0.quantity >= #{min_q} AND f0.secret = FALSE")
  )
  |> Repo.all()
end
```

Yet if you try to compile the above code it fails:

```text
Compiling 1 file (.ex)

== Compilation error in file lib/basket/goods.ex ==
** (Ecto.Query.CompileError) to prevent SQL injection attacks, fragment(...) 
does not allow strings to be interpolated as the first argument via the `^` 
operator, got: `"f0.quantity >= #{min_q} AND f0.secret = FALSE"`
```

What about passing arguments via fragment?

```
# Safe
def c_get_fruit(min_q) do
  min_q = String.to_integer(min_q)
  from(
    f in Fruit,
    where: fragment("f0.quantity >= ? AND f0.secret = FALSE", ^min_q)
  )
  |> Repo.all()
end
```

The above code is safe because the external user input is safely parameterized into the query. What if you decide to pass arguments directly into raw SQL?

```
# Safe
def d_get_fruit(min_q) do
  q = """
  SELECT f.id, f.name, f.quantity, f.secret
  FROM fruits AS f
  WHERE f.quantity > $1 AND f.secret = FALSE
  """
  {:ok, %{rows: rows}} =
    Ecto.Adapters.SQL.query(Repo, q, [String.to_integer(min_q)])
end
```

The above code is safe, similar to the fragment example, because the user input is being safely parameterized. 

Constructing a SQL query string via user input, then passing it directly to the query function does lead to SQL injection: 

```
# Vulnerable to SQL injection
def e_get_fruit(min_q) do
  q = """
  SELECT f.id, f.name, f.quantity, f.secret
  FROM fruits AS f
  WHERE f.quantity > #{min_q} AND f.secret = FALSE
  """
  {:ok, %{rows: rows}} =
    Ecto.Adapters.SQL.query(Repo, q)
end
```

If you find yourself writing raw SQL, take care not to interpolate directly into the string, but rather use parameters for external input into the query.

## Server Side Request Forgery (SSRF)

Server Side Request Forgery (SSRF) is a critical vulnerability that has been the root cause of major data breaches. The problem is untrusted user input being used to make outbound HTTP requests, which leads to the exploitation of services reachable from your Phoenix application. 

When you create a server in most cloud providers today, for example AWS EC2, there will be a [metadata service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) exposed on a private IP address. In the case of AWS it's on `169.254.169.254`. If you send an HTTP request to:

`http://169.254.169.254/iam/security-credentials`

From the server, it will return credentials for the AWS account. If you write a web application (for example in Phoenix) where a user can enter a URL, and then view the response of an HTTP request sent to that URL, that functionality is potentially vulnerable to SSRF. For a real world incident see [the Capital One breach.](https://dl.acm.org/doi/pdf/10.1145/3546068)

Your reaction to this may be "This seems like an unsafe feature, considering they named an entire vulnerability class after it." You are not alone in this opinion, AWS introduced some SSRF specific mitigations in [2019 via IMDSv2](https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/), requiring HTTP requests to the metadata endpoint to have session authentication. 

The instance metadata service of cloud servers is not the only target for SSRF: services such as PostgreSQL, MySQL, Redis, Elasticsearch, even custom micro-services that you believe are not exposed to the public internet may be vulnerable to SSRF. Consider an internal server with vulnerabilities that can be exploited via HTTP requests, not directly exposed to the public internet. Yet if that network also has a Phoenix application vulnerable to SSRF, an attacker can go through the Phoenix server to attack the private server. 

To summarize, using an HTTP client does not necessarily mean your application is vulnerable to SSRF. Rather the following conditions must be met:

1. You are using external user input to construct URLs
2. An attacker is able to send HTTP requests to some vulnerable server on your network 

For an Elixir specific example consider the Req library:

```
req = Req.new(base_url: "https://api.github.com")

Req.get!(req, url: "/repos/sneako/finch").body["description"]
#=> "Elixir HTTP client, focused on performance"
```

It is possible to override the `base_url` value:

```
req = Req.new(base_url: "https://elixir-lang.org/")
user_input = "https://dashbit.co/blog"
Req.get!(req, url: user_input) 
```

The above code sends a request to `https://dashbit.co/blog`, NOT `https://elixir-lang.org/`. 

Consider a similar example in Tesla:

```
plug Tesla.Middleware.BaseUrl, "https://example.com/foo"

MyClient.get("http://example.com/bar") # equals to GET http://example.com/bar
```

Even if you are setting a base URL in your application, don't treat it as a security barrier, because as these examples show it can be overwritten. Take care to avoid sending HTTP requests based on user input if you can avoid it, and be mindful of services on the same network as your Phoenix application that could be exploited via SSRF.

## Cross Origin Resource Sharing (CORS) Misconfiguration 

Cross Origin Resource Sharing (CORS) is a feature in modern web browsers which can be used to bypass the same origin policy, which is useful because your application can now load resources from a different site in the user's web browser. This is normally restricted by default. 

Consider a Phoenix API with a single page application (SPA) on a different domain:

`app.example.com`  - React frontend 

`api.example.com`  - Backend in Elixir/Phoenix 

The frontend `(app.example.com)` needs to fetch information about the current user, however the origins of these projects are different. The user's web browser will block the request unless CORS is enabled between the sites.

Setting the following in the Phoenix application:

```
plug CORSPlug, origin: ["https://app.example.com"]
```

Is the correct way to do this. However it is also possible to set a policy that is far too broad, for example:

```
plug CORSPlug, origin: ~r/^http.*/
```

This is a major security risk, because now a malicious site loaded by a user who is logged into the application can read sensitive data, for example API keys. Take care to ensure only trusted sites are allowed here. 

## Broken Access Control

In Phoenix controllers the standard way to handle authorization is putting the current user in the assigns, and then doing:

```
user = conn.assigns.current_user
```

Many projects add this as a third argument in the controller actions:

```
def action(conn, _) do
  args = [conn, conn.params, conn.assigns.current_user]
  apply(__MODULE__, action_name(conn), args)
end
```

This is the correct approach. The wrong approach is to accept arbitrary user input when making authorization decisions, for example:

```
# Not safe
def index(conn, %{"user" => user_email})
  user = Accounts.get_user_by_email(user_email)
```

In the above example an attacker can simply change the submitted `user_email` string to an arbitrary value to perform an action as a different user. Using `conn.assigns.current_user` avoids this problem. 

Related to the above concept, the design of Ecto in Phoenix takes the risk of mass assignment into consideration, because you have to explicitly define what parameters are allowed to be set from user supplied data.  Consider a simple users schema:

```
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :is_admin, :boolean 

    timestamps(type: :utc_datetime)
  end


  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :is_admin])
    |> validate_email()
    |> validate_password(opts)
  end
```

Assume that the corresponding signup form is exposed to the public internet. Can you spot the vulnerability? The problem is that `:is_admin` should never be set via external user input. Anyone on the public internet can now create a user where `:is_admin` is set to true in the database, which is likely not the intent of the developer.

## Cross Site Scripting (XSS) 

By default, user input in Phoenix is escaped so that:

```
<%= "<hello>" %>
```

is shown in your browser as:

```text
&lt;hello&gt;
```

Note that this looks like a normal string of `<hello>` from an end user perspective, the `&lt;` and `&gt;` are only visible if you inspect the page with your browser tools. 

It is possible to bypass this protection via the `raw/1` function. For example, consider the string `<b>hello</b>`. 

```
# This will render the literal string <b>hello</b>
<%= "<b>hello</b>" %>

# This will render a bold hello 
<%= raw "<b>hello</b>" %>
```

With the ability to inject script tags, an attacker now has the ability to execute JavaScript in a victim's browser, for example by submitting a string such as: 

```html
<script>alert(1)</script>
```

If someone submits the above input to your application, and it is displayed to logged in users, you have a serious problem. See the [2005 MySpace worm](https://en.wikipedia.org/wiki/Samy_(computer_worm)) for a real world example of this. 

User input should never be passed into the `raw/1` function. There are some additional vectors for XSS in Phoenix applications, for example consider the following controller functions: 


```
def html_resp(conn, %{"i" => i}) do
  html(conn, "<html><head>#{i}</head></html>")
end
```

Because the HTML is being generated from user input, the function is vulnerable to XSS. This can also happen with `put_resp_content_type`:

```
def send_resp_html(conn, %{"i" => i}) do
  conn
  |> put_resp_content_type("text/html")
  |> send_resp(200, "#{i}")
end
```

File uploads can also lead to XSS.

```
def new_upload(conn, _params) do
  render(conn, "new_upload.html")
end

def upload(conn, %{"upload" => upload}) do
  %Plug.Upload{content_type: content_type, filename: filename, path: path} = upload
  ImgServer.put(filename, %{content_type: content_type, bin: File.read!(path)})
  redirect(conn, to: Routes.page_path(conn, :view_photo, filename))
end

def view_photo(conn, %{"filename" => filename}) do
  case ImgServer.get(filename) do
    %{content_type: content_type, bin: bin} ->
      conn
      |> put_resp_content_type(content_type)
      |> send_resp(200, bin)
    _ ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(404, "Not Found")
  end
end
```

User input determines the `content-type` of the file. There is no validation on the type of file being uploaded, meaning `content-type` can be set so an HTML page is rendered. This is the source of the vulnerability. Consider the file `xss.html`, with the contents:

```html
<html><script>alert(1)</script></html>
```

This will result in JavaScript being executed in the browser of the victim who views the image. Restricting the `put_resp_content_type` argument to only image files would fix this vulnerability. 


## Cross Site Request Forgery (CSRF)

### Standard CSRF in HTML forms

Cross site request forgery (CSRF) is a vulnerability that exists due to a quirk in how web browsers work. Consider a social media website that is vulnerable to CSRF. An attacker creates a malicious website aimed at legitimate users. When a victim visits the malicious site, it triggers a POST request in the victim’s browser, sending a message that was written by the attacker. This results in the victim’s account making a post written by the attacker.

But why is this possible? Shouldn't the web browser block POST requests initiated by a different website? There is a cookie feature called SameSite that addresses this problem, however it's good to understand what CSRF is and why Phoenix has built in protections. 

Consider the following form:

```html
<form action="/posts" method="post">

  <label for="post_title">Title</label>
  <input id="post_title" name="post[title]" type="text">

  <label for="post_body">Body</label>
  <textarea id="post_body" name="post[body]">
  </textarea>

  <div>
    <button type="submit">Save</button>
  </div>
</form>

```

This maps to the following HTTP request:

```http_request_and_response
POST /posts HTTP/1.1
Host: example.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 53

post[title]=My+Title&post[body]=This+is+the+body
```

An attacker can embed the following form on `attacker.com`:

```html
<form action="https://example.com/posts" method="post">

  <label for="post_title">Title</label>
  <input id="post_title" name="post[title]" type="text" value="Attacker post">

  <label for="post_body">Body</label>
  <textarea id="post_body" name="post[body]">This post was written by the bad guy</textarea>

  <div>
    <button type="submit">Save</button>
  </div>
</form>
```

Note that this form does not even have to be visible to the victim user. When the user visits `attacker.com` the form will automatically submit a POST request on behalf of the victim, with the victim's current session cookie, to the vulnerable site. 

The way most web frameworks, including Phoenix, mitigate this vulnerability is by requiring a CSRF token when submitting a form.

```html
<!-- A typical CSRF token seen in a Phoenix form -->
<input name="_csrf_token" type="hidden" hidden="" 
  value="WUZXJh07BhAIJ24jP1d-KQEpLwYmMDwQ0-2eYNLH_x8oHoO_qv_HJDqZ">
```

This changes the previous HTTP request to:

```http_request_and_response
POST /posts HTTP/1.1
Host: example.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 53

post[title]=My+Title&post[body]=This+is+the+body&post[_csrf_token]=WUZXJh07BhAIJ24jP1d-KQEpLwYmMDwQ0-2eYNLH_x8oHoO_qv_HJDqZ
```

Because the token is randomly generated, an attacker cannot predict what the value will be. The application is safe against CSRF attacks because Phoenix checks the value of this token by default via the `:protect_from_forgery` plug, which is included in the default `:browser` pipeline of a new Phoenix project:

```
# router.ex

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {CarafeWeb.LayoutView, :root}
    plug :protect_from_forgery      # <-- Checks the CSRF token value
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end
```

CSRF protections are included in Phoenix by default, so your application is most likely not vulnerable if you are using the default settings. 

### Action Re-Use CSRF 

Most descriptions of CSRF focus on state changing POST requests and the need for random tokens, as was just covered. Is CSRF possible with a GET request? Yes, GET requests should never be used to perform state changing actions in a web application (place an order, transfer money, etc) because they cannot be protected against CSRF in the same way POST requests can. 

Consider the following form:

```heex
<.form :let={f} for={@bio_changeset} action={~p"/users/settings/edit_bio"} method="post" id="edit_bio">
  <div class="pt-4">
    <%= label f, :bio %>
    <%= textarea f, :bio, required: true, class: "" %>
    <%= error_tag f, :bio %>
  </div>

  <div>
    <%= submit "Update Bio", class: "" %>
  </div>
</.form>
```

Submitting this form triggers a POST request:

```text
[info] POST /users/settings/edit_bio
[debug] Processing with CarafeWeb.UserSettingsController.edit_bio/2
  Parameters: %{"_csrf_token" => "cigMDlcdAnxbWW88OAAiBHoZZ3cmCW0l1refzZ7D666RWvjCLi02UZXq", "user" => %{"bio" => "My bio here"}}
  Pipelines: [:browser, :require_authenticated_user]
```

The important point is that the above parameters match the route and controller action:

```
# router.ex
post "/users/settings/edit_bio", UserSettingsController, :edit_bio

# user_settings_controller.ex
def edit_bio(conn, %{"user" => params}) do
  case Accounts.update_user_bio(conn.assigns.current_user, params) do
    {:ok, _bio} ->
      conn
      |> put_flash(:info, "Bio Update Successful")
      |> redirect(to: Routes.user_settings_path(conn, :edit))
    {:error, changeset} ->
      render(conn, "edit.html", bio_changeset: changeset)
  end
end
```

The parameters:

```
%{"_csrf_token" => "cigMDlcdAnxbWW88OAAiBHoZZ3cmCW0l1refzZ7D666RWvjCLi02UZXq", "user" => %{"bio" => "My bio here"}}
```

Match the `edit_bio/2` action. Note that the `_csrf_token` is processed in the router by the plug `:protect_from_forgery` built into Phoenix. 

Now consider the following update to the router:

```
# router.ex
get "/users/settings/edit_bio", UserSettingsController, :edit_bio
post "/users/settings/edit_bio", UserSettingsController, :edit_bio
```

Allowing access to the `edit_bio/2` controller action via a GET request introduces an action re-use CSRF vulnerability. If the victim visits the following URL:

`/users/settings/edit_bio?user%5Bbio%5D=Hacked+LOL`

It will trigger the following:

```text
[info] GET /users/settings/edit_bio
[debug] Processing with CarafeWeb.UserSettingsController.edit_bio/2
  Parameters: %{"user" => %{"bio" => "Hacked LOL"}}
  Pipelines: [:browser, :require_authenticated_user]
```

These parameters will match the `edit_bio/2` controller action, updating the user biography. The key lesson here is that state changing actions (transferring money, creating a post, updating account information) should occur via a POST request with proper CSRF protections, never via a GET request. 

## Further Reading

The Erlang Ecosystem Foundation also publishes in-depth documents which are relevant for Erlang, Elixir, and Phoenix developers. These include:

  * [Web Application Security Best Practices for BEAM languages](https://security.erlef.org/web_app_security_best_practices_beam/)

  * [Secure Coding and Deployment Hardening Guidelines](https://security.erlef.org/secure_coding_and_deployment_hardening/)
