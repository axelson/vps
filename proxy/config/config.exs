# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :logger,
  level: :debug

config :proxy,
  cert_mode: "local",
  site_encrypt_domains: ["pham.jasonaxelson.com", "depviz.jasonaxelson.com", "makeuplive.jasonaxelson.com"],
  site_encrypt_db_folder: "/home/jason/dev/vps/proxy/tmp",
  depviz_domain: "depviz.test",
  makeuplive_domain: "makeuplive.test",
  site_encrypt_internal_port: 4106

config :master_proxy,
  http: [:inet6, port: 4102],
  https: [:inet6, port: 4103]

config :proxy, ProxyWeb.Endpoint,
  http: [port: 4104],
  https: [port: 4105],
  url: [host: "localhost", port: 4104],
  secret_key_base: "//YcYyKOATqeqDuhCCjGuk0jpsZLR/KwcFlePCc9Cqab5WBIbkVXYk8HlTeHVLJt",
  render_errors: [view: ProxyWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Proxy.PubSub,
  live_view: [signing_salt: "B4RFj8oi"]

config :gviz, GVizWeb.Endpoint,
  url: [host: "depviz.test", port: 80],
  hostname: "depviz.test",
  secret_key_base: "8xJzBHfqJr4addPiUqlefBIipUwmvDirioranvyHijBkSYSviZHK2WKoAjQsYTqF",
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: GVizWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GViz.PubSub,
  code_reloader: false

config :makeup_live, MakeupLiveWeb.Endpoint,
  url: [host: "makeuplive.test", port: 80],
  hostname: "makeuplive.test",
  secret_key_base: "cWT5GRJqD2MEmsQfeK86J2HgmZxi6YA/Fx/Y8wjhRnnAVZO0uJz+aI+2Nsck71dF",
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MakeupLive.PubSub,
  server: false,
  cache_static_manifest: "priv/static/cache_manifest.json",
  live_view: [signing_salt: "NpREzhguz87xA0eEUC6IcMT2PLRDIuCw"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
