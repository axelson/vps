import Config

# Select domain set at build time via VPS_INSTANCE env var.
# Defaults to "poc3" if not set.
#
# Usage:
#   VPS_INSTANCE=production MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
#   VPS_INSTANCE=poc3       MIX_TARGET=x86_64 MIX_ENV=prod mix firmware
#
# Domain config can also be overridden at runtime via /data/.target.domain.exs
# (see docs/notes/bootstrapping.md).

{main_host, endpoint_configs} =
  case System.get_env("VPS_INSTANCE", "poc3") do
    "production" ->
      {"pham.jasonaxelson.com",
       [
         {:gviz, GVizWeb.Endpoint, "depviz.jasonaxelson.com"},
         {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.jasonaxelson.com"},
         {:sketchpad, SketchpadWeb.Endpoint, "sketch.jasonaxelson.com"},
         {:jamroom, JamroomWeb.Endpoint, "jamroom.jasonaxelson.com"}
       ]}

    "poc3" ->
      {"poc3.jasonaxelson.com",
       [
         {:gviz, GVizWeb.Endpoint, "depviz.poc3.jasonaxelson.com"},
         {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.poc3.jasonaxelson.com"},
         {:sketchpad, SketchpadWeb.Endpoint, "sketch.poc3.jasonaxelson.com"},
         {:jamroom, JamroomWeb.Endpoint, "jamroom.poc3.jasonaxelson.com"}
       ]}
  end

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: [main_host] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: main_host, port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
