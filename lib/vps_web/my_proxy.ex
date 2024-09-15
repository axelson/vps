defmodule VpsWeb.MyProxy do
  use MainProxy.Proxy

  @impl MainProxy.Proxy
  def backends do
    site_configurations =
      Application.fetch_env!(:vps, :endpoint_configs)
      |> Enum.map(fn {_app, endpoint, hostname} ->
        %{
          domain: hostname,
          phoenix_endpoint: endpoint
        }
      end)

    List.flatten([
      # Needed for site_encrypt
      %{path: ~r/^\/.well-known\/acme-challenge\//, phoenix_endpoint: VpsWeb.Endpoint},
      site_configurations,
      %{path: ~r/^\/logs/, phoenix_endpoint: VpsWeb.Endpoint},
      %{path: ~r/^\/live/, phoenix_endpoint: VpsWeb.Endpoint},
      %{
        plug: VpsWeb.DefaultPlug
      }
    ])
  end

  # Optional callback
  @impl MainProxy.Proxy
  def merge_config(:https, opts) do
    Config.Reader.merge(opts, SiteEncrypt.https_keys(VpsWeb.Endpoint))
  end

  def merge_config(_, opts), do: opts
end
