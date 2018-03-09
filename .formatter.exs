locals_without_parens = [
  # Phoenix.Channel
  intercept: 1,

  # Phoenix.Router
  connect: 3,
  connect: 4,
  head: 3,
  head: 4,
  pipe_through: 1,
  resources: 2,
  resources: 3,
  resources: 4,
  trace: 4,

  # Phoenix.Controller
  action_fallback: 1,

  # Phoenix.Endpoint
  socket: 2,

  # Phoenix.Socket
  channel: 2,
  channel: 3,

  # Phoenix.ChannelTest
  assert_broadcast: 2,
  assert_broadcast: 3,
  assert_push: 2,
  assert_push: 3,
  assert_reply: 2,
  assert_reply: 3,
  assert_reply: 4,
  refute_broadcast: 2,
  refute_broadcast: 3,
  refute_push: 2,
  refute_push: 3,
  refute_reply: 2,
  refute_reply: 3,
  refute_reply: 4,

  # Phoenix.ConnTest
  assert_error_sent: 2
]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
