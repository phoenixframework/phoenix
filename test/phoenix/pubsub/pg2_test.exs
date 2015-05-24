Application.put_env(:phoenix, :pubsub_test_adapter, Phoenix.PubSub.PG2)
Code.require_file "../../support/pubsub_setup.exs", __DIR__
