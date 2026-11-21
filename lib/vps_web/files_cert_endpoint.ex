defmodule VpsWeb.FilesCertEndpoint do
  @moduledoc """
  Holds file_hosting's isolated certificate and answers its ACME challenges (see
  `VpsWeb.Certs`). It serves nothing else; file_hosting itself stays unaware of
  certificates.
  """

  use SiteEncrypt.Phoenix.Endpoint, otp_app: :vps

  plug :not_found

  @impl SiteEncrypt
  def certification do
    SiteEncrypt.configure(
      VpsWeb.Certs.configure_opts(:files, [VpsWeb.Certs.hostname(__MODULE__)])
    )
  end

  defp not_found(conn, _opts), do: Plug.Conn.send_resp(conn, 404, "Not found")
end
