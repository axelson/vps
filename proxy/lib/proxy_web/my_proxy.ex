defmodule ProxyWeb.MyProxy do
  use MasterProxy,
    backends: [
      # Needed for site_encrypt
      %{path: ~r/^\/.well-known\/acme-challenge\//, phoenix_endpoint: ProxyWeb.Endpoint},
      %{
        domain: Application.fetch_env!(:proxy, :depviz_domain),
        phoenix_endpoint: GVizWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:proxy, :makeuplive_domain),
        phoenix_endpoint: MakeupLiveWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:proxy, :sketch_domain),
        phoenix_endpoint: SketchpadWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:proxy, :jamroom_domain),
        phoenix_endpoint: JamroomWeb.Endpoint
      }
    ]

  # Optional callback
  @impl MasterProxy
  def merge_config(:https, opts) do
    Config.Reader.merge(opts, SiteEncrypt.https_keys(ProxyWeb.Endpoint))
  end

  def merge_config(:http, opts), do: opts
end
