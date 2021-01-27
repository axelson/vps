import Config

config :master_proxy,
  http: [:inet6, port: 4000],
  backends: [
    %{
      host: ~r/^depviz\.jasonaxelson\.com$/,
      phoenix_endpoint: GVizWeb.Endpoint
    },
    %{
      host: ~r/^makeuplive\.jasonaxelson\.com$/,
      phoenix_endpoint: MakeupLiveWeb.Endpoint
    }
  ]

config :gviz, GVizWeb.Endpoint,
  url: [host: "depviz.jasonaxelson.com"],
  #http: [port: 80],
  #https: [port: 443],
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: GVizWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GViz.PubSub,
  code_reloader: false

config :gviz, :phoenix_endpoint, GVizWeb.Endpoint

config :gviz,
  namespace: GViz,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt])

config :makeup_live, MakeupLiveWeb.Endpoint,
  url: [host: "makeuplive.jasonaxelson.com", port: 443],
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MakeupLive.PubSub,
  server: false,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  live_view: [signing_salt: "NpREzhguz87xA0eEUC6IcMT2PLRDIuCw"]
