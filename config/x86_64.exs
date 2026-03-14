import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz-poc.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive-poc.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch-poc.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom-poc.jasonaxelson.com"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :https,
  port: 443,
  endpoint_configs: endpoint_configs,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["poc.jasonaxelson.com"] ++ domains

config :vps, Vps.Repo, database: "/data/vps.db"

config :vps, VpsWeb.Endpoint,
  url: [host: "poc.jasonaxelson.com", port: 80],
  render_errors: [view: VpsWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Vps.PubSub,
  server: false
