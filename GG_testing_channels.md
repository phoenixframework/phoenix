As developers we typically value tests since they help to 'future-proof' our applications by
minimizing regression and provide updated documentation. Phoenix recognizes this and helps
make it easier to write tests by providing conveniences for testing its different parts,
including Channels.

In the Channels guide it was mentioned that a "Channel" is a layered system with different
components. Given this, there would be cases when writing unit tests for our Channel
functions may not be enough. We may want to verify that its different moving parts
are working together as we expect. This integration testing would assure us that we
correctly defined our channel route, the channel module, and its callbacks; and that
the lower-level layers such as the PubSub and Transport are configured correctly and
are working as intended.

#### The Channel Test Helpers Module

When you generate a new Phoenix application, a `test/support/channel_case.ex` file is
also generated for you. This file houses the `MyApp.ChannelCase` module which we will
use for all our integration tests for our channels. It automatically imports conveniences
for testing channels and the Ecto model and query functions(if we use Ecto).

Some of the helper functions provided there are for triggering callback functions in our
channel. The others are there to provide us with special assertions that apply only to channels.

If we need to add our own helper function that we would only use in channel tests, we
would add it to `MyApp.ChannelCase` by defining it there and ensuring `MyApp.ChannelCase`
is imported every time it is `use`d. For example:

```elixir
defmodule MyApp.ChannelCase do
  ...

  using do
    quote do
      ...
      import MyApp.ChannelCase
    end
  end

  def a_channel_test_helper() do
    # code here
  end
end
```

#### Set Up Channel Tests
