defmodule FileHostingWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :file_hosting

  # No session, cookies, or body parsers: the API reads upload bodies itself and
  # authenticates with a bearer token only.
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Head
  plug FileHostingWeb.Router
end
