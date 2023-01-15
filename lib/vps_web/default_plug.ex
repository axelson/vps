defmodule VpsWeb.DefaultPlug do
  import Phoenix.LiveView.Helpers

  def init(opts), do: opts

  def call(conn, _opts) do
    assigns = %{
      domains: domains()
    }

    html = ~H"""
    <html>
      <head>
        <title>
          VPS
        </title>
      </head>
      <body>
        <h2>Available domains:</h2>
        <ul>
          <%= for domain <- @domains do %>
            <li><a href={domain}><%= domain %></a></li>
          <% end %>
        </ul>
      </body>
    </html>
    """

    iodata = Phoenix.HTML.Safe.to_iodata(html)
    html = List.to_string(iodata)

    Plug.Conn.send_resp(conn, 200, html)
  end

  defp build_url(domain) do
    http_mode = Application.fetch_env!(:vps, :http_mode)

    scheme =
      case http_mode do
        :https -> "https://"
        :http -> "http://"
      end

    port =
      case http_mode do
        :http ->
          scheme_opts = Application.get_env(:main_proxy, :http, [])
          :proplists.get_value(:port, scheme_opts)

        :https ->
          scheme_opts = Application.get_env(:main_proxy, :https, [])
          :proplists.get_value(:port, scheme_opts)
      end

    scheme <> domain <> ":" <> to_string(port)
  end

  defp domains do
    Enum.map(Application.fetch_env!(:vps, :endpoint_configs), fn {_, _, domain} -> domain end)
    |> Enum.map(&build_url/1)
  end
end
