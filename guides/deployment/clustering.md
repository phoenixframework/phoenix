# Clustering

Elixir and the Erlang VM have the incredible ability to be clustered together and pass messages seamlessly between nodes. To enable clustering, we need two distinct features:

* Node connection: different instances of the same service should communicate with each other. This is a feature of the Erlang VM.

* Service discovery: for a given service, you must be able to find the IP address of all instances. Phoenix ships with `dns_cluster` to provide out-of-the-box DNS-based service discovery but alternative methods may be used.

## DNS Discovery

Your clustering configuration is typically added to `rel/env.sh.eex`. This is a file that is executed before you release starts, and it is a perfect place to configure your application runtime based on your deployment environment. Here is a general skeleton:

```sh
# Uncomment if IPv6 is required
# export ECTO_IPV6="true"
# export ERL_AFLAGS="-proto_dist inet6_tcp"

# Erlang uses a port mapper daemon on each node,
# it by default runs on port 4369
export ERL_EPMD_PORT=4369

# Use the ports 4370-4372 for nodes to communicate.
export ERL_AFLAGS="-kernel inet_dist_listen_min 4370 inet_dist_listen_max 4372"

export RELEASE_DISTRIBUTION="name"
export RELEASE_NODE="app-${PLATFORM_DEPLOYMENT_SHA}@${PLATFORM_DEPLOYMENT_IP}"
export DNS_CLUSTER_QUERY="your-app.internal"
```

The script above is doing a couple things:

* It configures your app to use ports 4369, 4370, 4371, and 4372 for communication. You may need to explicitly expose those as internal TCP ports in your deployment platform (in addition to the HTTP port of your choice)

* It then configures your app to use fully qualified names. The name of each app will include the current deployment sha as `PLATFORM_DEPLOYMENT_SHA` (the name of the exact environment variable is platform dependent), so each deployment establishes its own cluster, and the current IP as `PLATFORM_DEPLOYMENT_IP` (also platform specific). If the IP is not available, you may be able to compute it as `NODE_IP=hostname | tr -d ' '`

* Then finally you define a DNS query which will be used to find the IPs of the other instances

Some platforms, such as [Fly.io](https://fly.io/docs/networking/private-networking/), [Railway](https://docs.railway.com/guides/private-networking), and [Render](https://render.com/docs/private-network#direct-ip-communication-advanced), provide private networks with DNS querying out of the box. You only need to adapt the `DNS_CLUSTER_QUERY` variable accordingly. Their documentation will guide you to setup it correctly or automate those steps via the CLI

Other platforms, such as [Digital Ocean App Platform](https://www.digitalocean.com/products/app-platform) and [Northflank](https://northflank.com/features/platform), allow nodes to directly connect to each other, but they do not provide DNS service discovery. In this next section, we explore different service discovery mechanisms.

## Alternative discovery mechanisms

While not all platforms support DNS queries for service discovery, there are many alternative strategies for connecting your nodes together. Please checkout the following libraries:

  * [libcluster](https://github.com/bitwalker/libcluster) - provides strategies for connecting your nodes using gossip protocols, kubernetes, ec2, and others

  * [libcluster_postgres](https://github.com/supabase/libcluster_postgres/) - a plugin for `libcluster` which uses PostgreSQL for node discovery. Given most applications already use a database, and likely PostgreSQL, this is a suitable option which does not require additional setup

When using the libraries above, you can likely remove `dns_query` from your application dependencies.

## `epmd`-less deployment

In the snippet above, we used ports 4369, 4370, 4371, and 4372. However, the Erlang VM allows running the distribution over a fixed port, also known as `epmd`-less deployments. To enable such, do this.

Remove the lines:

```sh
export ERL_EPMD_PORT=4369
export ERL_AFLAGS="-kernel inet_dist_listen_min 4370 inet_dist_listen_max 4372"
```

Add a file rel/vm.args.eex with the following:

```
-start_epmd false -erl_epmd_port 6789
```

Add a file rel/remote.vm.args.eex with the following:

```
-start_epmd false -erl_epmd_port 6789 -dist_listen false
```

And now only port 6789 (in addition to the HTTP one) needs to be exposed internally between instances.

## Clustering and long-polling transports

Phoenix supports two types of transports for its Socket implementation: WebSocket, and Long-Polling. When generating a Phoenix project, you can see the default configuration set in the generated `endpoint.ex` file:

```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```

This configuration tells Phoenix that both the WebSocket and the Long-Polling options are available, and based on the client's network conditions, Phoenix will first attempt to connect to the WebSocket, falling back to the Long-Poll option after the configured timeout found in the generated `app.js` file:

```javascript
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})
```

If you are running more than one machine in production, which is the recommended approach in most cases, this automatic fallback comes with an important caveat. If you want Long-Polling to work properly, your application must either:

1. Utilize the Erlang VM's clustering capabilities, so the default `Phoenix.PubSub` adapter can broadcast messages across nodes

2. Choose a different `Phoenix.PubSub` adapter (such as `Phoenix.PubSub.Redis`)

3. Or your deployment option must implement sticky sessions, ensuring that all requests for a specific session go to the same machine

The reason for this is simple. While a WebSocket is a long-lived open connection to the same machine, long-polling works by opening a request to the server, waiting for a timeout or until the open request is fulfilled, and repeating this process. In order to preserve the state of the user's connected socket and to preserve the behaviour of a socket being long-lived, the user's process is kept alive, and each long-poll request attempts to find the user's stateful process. If the stateful process is not reachable, every request will create a new process and a new state, thereby breaking the fact that the socket is long-lived and stateful.
