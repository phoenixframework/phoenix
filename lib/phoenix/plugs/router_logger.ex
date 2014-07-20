defmodule Phoenix.Plugs.RouterLogger do
  import Phoenix.Controller.Connection

  @moduledoc """
  Plug to handle request logging at the router level

  Includes basic request logging of HTTP method and conn.path_info
  """

  def init(opts), do: opts

  def call(conn, level) do
    before_stamp = :os.timestamp()
    before = localtime_ms(before_stamp) |> format_time
    if level == :debug do
      IO.puts("#{before} #{conn.method}: #{inspect conn.path_info}")
    end
    Plug.Conn.register_before_send(conn, before_send(before_stamp, level))
  end

  defp before_send(before_stamp, level) when level in [:debug, :info, :error] do
    fn conn ->
      {_, _, before_micro} = before_stamp
      {_, _, after_micro} = :os.timestamp()
      diff = after_micro - before_micro
      before = localtime_ms(before_stamp) |> format_time

      #if we micro gets too big then use ms
      resp_time =  if diff > 1000 do
        "#{div(diff, 1000)}ms"
      else
        "#{diff}µs"
      end
      log(level, before, resp_time, conn)
      conn
    end
  end
  defp before_send(_, _), do: fn conn -> conn end

  defp log(:debug, before, resp_time, conn) do
    IO.puts """
        controller: #{controller_module(conn)}
        action:     #{action_name(conn)}
        accept:     #{response_content_type(conn)}
        parameters: #{inspect conn.params}
      resp_time=#{resp_time} status=#{conn.status} #{conn.method}
    """
  end

  defp log(level, before, resp_time, conn) do
    IO.puts "#{before} resp_time=#{resp_time} status=#{conn.status} #{conn.method}: #{inspect conn.path_info}"
  end

  defp localtime_ms() do
    localtime_ms(:os.timestamp())
  end
  #Source https://gist.github.com/dergraf/2216802GOOGLE_PLACES 
  defp localtime_ms(now = {_, _, micro}) do
    {date, {hours, minutes, meconds}} = :calendar.now_to_local_time(now)
    {date, {hours, minutes, meconds, div(micro, 1000) |> rem(1000)}}
  end

  defp format_time({{yy, mm, dd}, {hh, mi, ss, ms}}) do
    [pad(yy), ?-, pad(mm), ?-, pad(dd), ?\s, pad(hh), ?:, pad(mi), ?:, pad(ss), ?:, pad(ms)]
  end

  defp pad(int) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad(int), do: Integer.to_string(int)

end
