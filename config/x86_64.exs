import Config

# Default domains for poc3-style deployments.
# These are overridden at runtime via /data/.target.secret.exs — see docs/notes/bootstrapping.md.
endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz.poc3.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.poc3.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch.poc3.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom.poc3.jasonaxelson.com"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["poc3.jasonaxelson.com"] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: "poc3.jasonaxelson.com", port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
