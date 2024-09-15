import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz.localhost"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.localhost"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch.localhost"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom.localhost"}
]

domains = Enum.map(endpoint_configs, fn {_, _, domain} -> domain end)

config :vps,
  http_mode: :http,
  port: 4000,
  endpoint_configs: endpoint_configs,
  cert_mode: "local",
  site_encrypt_domains: ["pham.test"] ++ domains,
  site_encrypt_db_folder: Path.join([System.get_env("HOME"), "dev/vps/vps/tmp"]),
  site_encrypt_internal_port: 4106

config :vps, Vps.Repo, database: "priv/database.db"

config :vps, VpsWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  http: [port: 4104],
  https: [port: 4105],
  url: [host: "localhost", port: 4104],
  secret_key_base: "//YcYyKOATqeqDuhCCjGuk0jpsZLR/KwcFlePCc9Cqab5WBIbkVXYk8HlTeHVLJt",
  render_errors: [view: ProxyWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Proxy.PubSub,
  live_view: [signing_salt: "B4RFj8oi"],
  watchers: []

config :gviz, GVizWeb.Endpoint,
  secret_key_base: "8xJzBHfqJr4addPiUqlefBIipUwmvDirioranvyHijBkSYSviZHK2WKoAjQsYTqF",
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: GVizWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GViz.PubSub,
  code_reloader: false

config :makeup_live, MakeupLiveWeb.Endpoint,
  secret_key_base: "cWT5GRJqD2MEmsQfeK86J2HgmZxi6YA/Fx/Y8wjhRnnAVZO0uJz+aI+2Nsck71dF",
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MakeupLive.PubSub,
  server: false,
  cache_static_manifest: "priv/static/cache_manifest.json",
  live_view: [signing_salt: "NpREzhguz87xA0eEUC6IcMT2PLRDIuCw"]

config :sketchpad, SketchpadWeb.Endpoint,
  secret_key_base: "BCqHloAfzORpn/TX90PB9GULWVRZpjwegD4U8T1on/RUmEYTjkVGLC2YKFhkhLiS",
  render_errors: [view: SketchpadWeb.ErrorView, accepts: ~w(html json)],
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  server: false,
  cache_static_manifest: "priv/static/cache_manifest.json",
  pubsub_server: Sketchpad.PubSub,
  code_reloader: false

config :jamroom, JamroomWeb.Endpoint,
  secret_key_base: "/YVe81SiI1By9z26z0Zxc3VWNWdiOx76CjMM0/kw6GjorvtLkWnSP36fUwqwtd3D",
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: JamroomWeb.ErrorView, accepts: ~w(html json), layout: false],
  server: false,
  cache_static_manifest: "priv/static/cache_manifest.json",
  pubsub_server: Jamroom.InternalPubSub,
  live_view: [signing_salt: "1lqe1yckbnWuFu992XoMQwqb+kCQb1KI"],
  code_reloader: false

config :main_proxy,
  http: [:inet6, port: 4000],
  https: [:inet6, port: 4103]

# Configures Elixir's Logger
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  # format: "[$level] $message\n"
  metadata: [:request_id],
  stacktrace_depth: 20,
  plug_init_mode: :runtime

config :logger, backends: [:console, RingLogger]
