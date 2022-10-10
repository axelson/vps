defmodule VpsWeb.DefaultPlug do
  import Phoenix.LiveView.Helpers

  def init(opts), do: opts

  def call(conn, _opts) do
    assigns = %{
      domains:
        [
          Application.fetch_env!(:vps, :depviz_domain),
          Application.fetch_env!(:vps, :makeuplive_domain),
          Application.fetch_env!(:vps, :sketch_domain),
          Application.fetch_env!(:vps, :jamroom_domain)
        ]
        |> Enum.map(&build_url/1)
    }

    html = ~H"""
    <html>
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
          scheme_opts = Application.get_env(:master_proxy, :http, [])
          :proplists.get_value(:port, scheme_opts)

        :https ->
          scheme_opts = Application.get_env(:master_proxy, :https, [])
          :proplists.get_value(:port, scheme_opts)
      end

    scheme <> domain <> ":" <> to_string(port)
  end
end
