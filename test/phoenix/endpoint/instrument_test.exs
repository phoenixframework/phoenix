defmodule Phoenix.Endpoint.InstrumentTest do
  # Cannot run async because of capture_log related assertions
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Endpoint.Instrument

  @config [instrumenters: [__MODULE__.MyInstrumenter, __MODULE__.MyOtherInstrumenter]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule MyInstrumenter do
    def my_event(:start, compile_meta, runtime_meta) do
      send self(), {__MODULE__, {:my_event_start, %{compile_meta: compile_meta, runtime_meta: runtime_meta}}}
      :ok
    end

    def my_event(:stop, duration, res) do
      send self(), {__MODULE__, {:my_event_stop, %{duration: duration, res: res}}}
    end

    def common_event(:start, _, _) do
      send self(), {__MODULE__, :common_event_start}
    end

    def common_event(:stop, _, _) do
      send self(), {__MODULE__, :common_event_stop}
    end

    def raising_event(_, _, _) do
      raise "oops"
    end
  end

  defmodule MyOtherInstrumenter do
    def common_event(:start, _, _) do
      send self(), {__MODULE__, :common_event_start}
    end

    def common_event(:stop, _, _) do
      send self(), {__MODULE__, :common_event_stop}
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  test "basic usage of instrument/3" do
    import Endpoint

    return_value = instrument :my_event, %{run: :time}, fn ->
      send self(), :inside_instrument_block
      :normal_return_value
    end

    assert return_value == :normal_return_value

    assert_receive {__MODULE__.MyInstrumenter, {:my_event_start, start_data}}
    assert start_data.compile_meta.file == __ENV__.file
    assert start_data.runtime_meta == %{run: :time}

    assert_receive :inside_instrument_block

    assert_receive {__MODULE__.MyInstrumenter, {:my_event_stop, stop_data}}
    assert stop_data.res == :ok
    assert is_integer(stop_data.duration)
    assert stop_data.duration >= 0
  end

  test "raising inside the block passed to instrument/3" do
    import Endpoint

    assert_raise RuntimeError, "oops", fn ->
      instrument :my_event, %{runtime: :ok}, fn -> raise("oops") end
    end

    assert_receive {__MODULE__.MyInstrumenter, {:my_event_start, _}}
    assert_receive {__MODULE__.MyInstrumenter, {:my_event_stop, _}}
  end

  test "if no instrumenter is interested in an event, nothing is called" do
    import Endpoint

    instrument :uninteresting_event, fn ->
      send self(), :uninteresting_event_happened
    end

    assert_receive :uninteresting_event_happened
    refute_receive {_, _}
  end

  test "multiple instrumenters interested in the same event" do
    import Endpoint

    instrument :common_event, fn ->
      send self(), :common_event_happened
    end

    assert_receive {__MODULE__.MyInstrumenter, :common_event_start}
    assert_receive {__MODULE__.MyOtherInstrumenter, :common_event_start}
    assert_receive :common_event_happened
    refute_receive :common_event_happened # just once!
    assert_receive {__MODULE__.MyInstrumenter, :common_event_stop}
    assert_receive {__MODULE__.MyOtherInstrumenter, :common_event_stop}
  end

  test "event callbacks that raise/throw" do
    import Endpoint

    log = capture_log fn ->
      :ok = instrument :raising_event, fn ->
        send self(), :ok
      end
    end

    assert_receive :ok
    # We have the correct stacktrace.
    assert log =~ Path.relative_to_cwd(__ENV__.file)
    assert log =~ "Instrumenter #{inspect __MODULE__.MyInstrumenter}.raising_event/3 failed.\n"
    # And we're sure the exception is logged twice:
    err = "** (RuntimeError) oops"
    assert Regex.scan(~r/#{Regex.escape(err)}$/m, log) == [[err], [err]]
  end

  test "Phoenix.Endpoint.instrument/4 macro proxies to the endpoint instrument function" do
    require Phoenix.Endpoint
    endpoint = Endpoint

    :ok = Phoenix.Endpoint.instrument endpoint, :my_event, %{run: :time}, fn ->
      send self(), :inside_instrument_block
      :ok
    end

    assert_receive {__MODULE__.MyInstrumenter, {:my_event_start, start_data}}
    assert start_data.compile_meta.file == __ENV__.file
    assert start_data.runtime_meta == %{run: :time}

    assert_receive :inside_instrument_block

    assert_receive {__MODULE__.MyInstrumenter, {:my_event_stop, stop_data}}
    assert stop_data.res == :ok
    assert is_integer(stop_data.duration)
    assert stop_data.duration >= 0
  end

  test "filter_values" do
    assert Instrument.filter_values(%{"foo" => "bar", "password" => "should_not_show"}, ["password"]) ==
           %{"foo" => "bar", "password" => "[FILTERED]"}
  end

  test "filter_values when a map has secret key" do
    assert Instrument.filter_values(%{"foo" => "bar", "map" => %{"password" => "should_not_show"}}, ["password"]) ==
           %{"foo" => "bar", "map" => %{"password" => "[FILTERED]"}}
  end

  test "filter_values when a list has a map with secret" do
    assert Instrument.filter_values(%{"foo" => "bar", "list" => [%{"password" => "should_not_show"}]}, ["password"]) ==
           %{"foo" => "bar", "list" => [%{"password" => "[FILTERED]"}]}
  end

  test "filter_values does not filter structs" do
    assert Instrument.filter_values(%{"foo" => "bar", "file" => %Plug.Upload{}}, ["password"]) ==
           %{"foo" => "bar", "file" => %Plug.Upload{}}

    assert Instrument.filter_values(%{"foo" => "bar", "file" => %{__struct__: "s"}}, ["password"]) ==
           %{"foo" => "bar", "file" => %{:__struct__ => "s"}}
  end

  test "filter_values does not fail on atomic keys" do
    assert Instrument.filter_values(%{:foo => "bar", "password" => "should_not_show"}, ["password"]) ==
           %{:foo => "bar", "password" => "[FILTERED]"}
  end
end
