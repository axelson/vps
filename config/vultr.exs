import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom.jasonaxelson.com"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["pham.jasonaxelson.com"] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: "pham.jasonaxelson.com", port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
