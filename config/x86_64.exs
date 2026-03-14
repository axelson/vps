import Config

# Select domain set at build time via VPS_INSTANCE env var.
# Defaults to "poc3" if not set.
#
# Usage:
#   VPS_INSTANCE=production MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
#   VPS_INSTANCE=poc3       MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
#   VPS_INSTANCE=qemu       MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
#
# Domain config can also be overridden at runtime via /data/.target.domain.exs
# (see docs/notes/bootstrapping.md).

{main_host, endpoint_configs, cert_mode, extra_vps_config} =
  case System.get_env("VPS_INSTANCE", "poc3") do
    "production" ->
      {"pham.jasonaxelson.com",
       [
         {:gviz, GVizWeb.Endpoint, "depviz.jasonaxelson.com"},
         {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.jasonaxelson.com"},
         {:sketchpad, SketchpadWeb.Endpoint, "sketch.jasonaxelson.com"},
         {:jamroom, JamroomWeb.Endpoint, "jamroom.jasonaxelson.com"}
       ], "production", []}

    "poc3" ->
      {"poc3.jasonaxelson.com",
       [
         {:gviz, GVizWeb.Endpoint, "depviz.poc3.jasonaxelson.com"},
         {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.poc3.jasonaxelson.com"},
         {:sketchpad, SketchpadWeb.Endpoint, "sketch.poc3.jasonaxelson.com"},
         {:jamroom, JamroomWeb.Endpoint, "jamroom.poc3.jasonaxelson.com"}
       ], "production", []}

    "qemu" ->
      {"poc.localhost",
       [
         {:gviz, GVizWeb.Endpoint, "depviz.localhost"},
         {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.localhost"},
         {:sketchpad, SketchpadWeb.Endpoint, "sketch.localhost"},
         {:jamroom, JamroomWeb.Endpoint, "jamroom.localhost"}
       ], "local", [site_encrypt_internal_port: 4106]}
  end

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
       [
         http_mode: :https,
         port: 443,
         endpoint_configs: endpoint_configs,
         cert_mode: cert_mode,
         site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
         site_encrypt_domains: [main_host] ++ domains
       ] ++ extra_vps_config

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: main_host, port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false

# HTTPS is not supported locally when running via qemu
# Theoretically this might be possible but I haven't tried to set it up
if System.get_env("VPS_INSTANCE") == "qemu" do
  for {app, endpoint, _} <- endpoint_configs do
    config app, endpoint, force_ssl: false
  end

  config :vps, VpsWeb.Endpoint, force_ssl: false

  config :vps,
    cert_mode: "local",
    http_mode: :http,
    # Internal listening port is 80 (mapped to 8080 externally by QEMU)
    port: 8080

  config :vps, VpsWeb.Endpoint, url: [host: main_host, port: 8080]
end
