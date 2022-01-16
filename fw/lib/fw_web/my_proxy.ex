defmodule FwWeb.MyFw do
  use MasterProxy,
    backends: [
      # Needed for site_encrypt
      %{path: ~r/^\/.well-known\/acme-challenge\//, phoenix_endpoint: FwWeb.Endpoint},
      %{
        domain: Application.fetch_env!(:fw, :depviz_domain),
        phoenix_endpoint: GVizWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:fw, :makeuplive_domain),
        phoenix_endpoint: MakeupLiveWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:fw, :sketch_domain),
        phoenix_endpoint: SketchpadWeb.Endpoint
      },
      %{
        domain: Application.fetch_env!(:fw, :jamroom_domain),
        phoenix_endpoint: JamroomWeb.Endpoint
      }
    ]

  # Optional callback
  @impl MasterProxy
  def merge_config(:https, opts) do
    Config.Reader.merge(opts, SiteEncrypt.https_keys(FwWeb.Endpoint))
  end

  def merge_config(:http, opts), do: opts
end
