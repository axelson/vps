defmodule VpsWeb.MyProxy do
  use MainProxy.Proxy

  @acme_challenge ~r/^\/.well-known\/acme-challenge\//

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

    isolated_challenges =
      for {cert_endpoint, hostname} <- VpsWeb.Certs.isolated() do
        %{domain: hostname, path: @acme_challenge, phoenix_endpoint: cert_endpoint}
      end

    List.flatten([
      # Needed for site_encrypt
      isolated_challenges,
      %{path: @acme_challenge, phoenix_endpoint: VpsWeb.Endpoint},
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
    opts
    |> Config.Reader.merge(SiteEncrypt.https_keys(VpsWeb.Endpoint))
    |> Keyword.put(:sni_fun, &sni_keys/1)
  end

  def merge_config(_, opts), do: opts

  # Isolated hostnames get their own certificate; :undefined falls back to the main one.
  # Paths are resolved per handshake, so a renewal (which clears :ssl's PEM cache) is
  # picked up without restarting the listener.
  defp sni_keys(hostname) do
    case List.keyfind(VpsWeb.Certs.isolated(), to_string(hostname), 1) do
      {cert_endpoint, _hostname} -> SiteEncrypt.https_keys(cert_endpoint)
      nil -> :undefined
    end
  end
end
