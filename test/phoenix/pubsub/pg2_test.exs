Application.put_env(:phoenix, :pubsub_test_adapter, Phoenix.PubSub.PG2)
Code.require_file "../../shared/pubsub_test.exs", __DIR__
