defmodule VpsWeb.DefaultPlug do
  import Phoenix.Component

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
    scheme =
      case Application.fetch_env!(:vps, :http_mode) do
        :https -> "https://"
        :http -> "http://"
      end

    port = Application.fetch_env!(:vps, :port)

    scheme <> domain <> ":" <> to_string(port)
  end

  defp domains do
    Enum.map(Application.fetch_env!(:vps, :endpoint_configs), fn {_, _, domain} -> domain end)
    |> Enum.map(&build_url/1)
  end
end
