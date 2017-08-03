# Running Asynchronous Tasks

There are many instances where we will have multiple things to do that aren't
dependent on each other. When we run into these cases, we would like to start
separate processes that are not linked to the caller. This allows the caller to
continue running if the new process crashes. To do this, we use
[`Task.Supervisor.`](http://elixir-lang.org/docs/stable/elixir/Task.Supervisor)

### Starting Our Supervisor

In `lib/hello.ex`, where our app is started, we can see that we have
`HelloWeb.Endpoint` as a supervisor, which is handling our web requests. If
we want to hand off async tasks to from our `HelloWeb.Endpoint` supervisor
to a `Task.Supervisor`, we need to start one here. Inside of the `children`
list, add:

```elixir
supervisor(Task.Supervisor, [[name: Hello.TaskSupervisor]])
```

Which gives us:

```elixir
defmodule Hello do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(HelloWeb.Endpoint, []),
      supervisor(Task.Supervisor, [[name: Hello.TaskSupervisor]]),
      # Start the Ecto repository
      worker(Hello.Repo, []),
      # Here you could define other workers and supervisors as children
      # worker(Hello.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HelloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

Now we have a `Task.Supervisor` that we can refer to as
`Hello.TaskSupervisor`, waiting to receive any tasks that we'd like to
offload from another process. Let's see what this does for us.

### Fire and Forget

Often we'd like to "fire and forget" certain types of work.  A common example
here would be to send an email to an end user in a controller, then sending
some sort of notification or redirect in the response without waiting for the
email to send. Our email needs to be handled in an async task so we don't block
our calling process (where the controller response will be sent).
Additionally, unlike some async tasks, we don't care about the result of the
task, so we don't need to await the result.  We like to say we can "fire and
forget" these types of tasks.

Since the result of the new async process and the calling process are
independent of each other, we need to make sure if something goes wrong in
our async task, it doesn't crash the calling process. To do this, we need a
separate supervisor that can supervise our async process. We can use the
`Hello.TaskSupervisor` that we created earlier for this, as we will see
below.

Let's prove that we can send a task to our supervisor that is completely
independent of the calling process, allowing the caller to continue running if
the task blows up.

In the new processes, we will crash it with `1/0` (which will raise
(ArithmeticError) bad argument in arithmetic expression), to make sure our
request still finishes despite the error. We will also sleep for 2 seconds, so
we can see that our calling process is not blocked by the async task runs.

```elixir
defmodule Hello.PageController do
  use Hello.Web, :controller

  def index(conn, _params) do

    Task.Supervisor.async_nolink(Hello.TaskSupervisor, fn ->
      :timer.sleep(2000)
      1 / 0
    end)

    render conn, "index.html"
  end
end
```

`async_nolink/2` accepts the name of a supervisor as the first argument, we
passed in the name of the supervisor we specified in `lib/hello.ex`.
The next argument is an anonymous function that will become a task supervised
by the passed in supervisor.  As the name suggested, this task will not be
linked to the calling process, allowing our request to finish when our task
fails.

When we spin up our server and visit our `"/"` route at `localhost:4000`, the
request finishes and responds as normal - followed by an arithmetic error after
a few seconds. Since the tasks aren't linked, we can execute any task using the
other supervisor, and our controller is able to send a response regardless of
the error.

It's worth noting that if these tasks fail, they won't be retried. Consider
building a solution using
[GenStage](https://hexdocs.pm/gen_stage/GenStage.html)
