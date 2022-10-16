import Config

endpoint_configs = [
  {:gviz, GVizWeb.Endpoint, "depviz.jasonaxelson.com"},
  {:makeup_live, MakeupLiveWeb.Endpoint, "makeuplive.jasonaxelson.com"},
  {:sketchpad, SketchpadWeb.Endpoint, "sketch.jasonaxelson.com"},
  {:jamroom, JamroomWeb.Endpoint, "jamroom.hassanshaikley.jasonaxelson.com"}
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

config :gviz, GVizWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  check_origin: false,
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: GVizWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GViz.PubSub,
  code_reloader: false

config :makeup_live, MakeupLiveWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  # check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MakeupLive.PubSub,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: false

config :sketchpad, SketchpadWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  render_errors: [view: SketchpadWeb.ErrorView, accepts: ~w(html json)],
  # check_origin: false,
  root: Path.dirname(__DIR__),
  cache_static_manifest: "priv/static/cache_manifest.json",
  pubsub_server: Sketchpad.PubSub,
  code_reloader: false,
  server: false

config :jamroom, JamroomWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: JamroomWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Jamroom.InternalPubSub,
  code_reloader: false

config :gviz, :phoenix_endpoint, GVizWeb.Endpoint

config :gviz, namespace: GViz

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

# Use shoehorn to start the main application. See the shoehorn
# docs for separating out critical OTP applications such as those
# involved with firmware updates.

config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# Nerves Runtime can enumerate hardware devices and send notifications via
# SystemRegistry. This slows down startup and not many programs make use of
# this feature.

config :nerves_runtime, :kernel, use_system_registry: false

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

config :nerves,
  erlinit: [
    hostname_pattern: "nerves-%s",
    # Workaround for https://github.com/nerves-project/nerves/issues/632
    env: "RELEASE_SYS_CONFIG=/srv/erlang/releases/0.1.0/sys"
  ]

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

keys =
  [
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_air_laptop.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_framework_laptop.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_desktop_rsa.pub"])
  ]
  |> Enum.filter(&File.exists?/1)

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

# Configure the network using vintage_net
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0",
     %{
       type: VintageNetEthernet,
       ipv4: %{method: :dhcp}
     }},
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :main_proxy,
  http: [:inet6, port: 80],
  https: [:inet6, port: 443]

config :site_encrypt, sites: [{VpsWeb.Endpoint, VpsWeb.SiteEncryptImpl}]

config :logger,
  backends: [RingLogger]

# config :mdns_lite,
#  # The `host` key specifies what hostnames mdns_lite advertises.  `:hostname`
#  # advertises the device's hostname.local. For the official Nerves systems, this
#  # is "nerves-<4 digit serial#>.local".  mdns_lite also advertises
#  # "nerves.local" for convenience. If more than one Nerves device is on the
#  # network, delete "nerves" from the list.
#
#  host: [:hostname, "nerves"],
#  ttl: 120,
#
#  # Advertise the following services over mDNS.
#  services: [
#    %{
#      name: "SSH Remote Login Protocol",
#      protocol: "ssh",
#      transport: "tcp",
#      port: 22
#    },
#    %{
#      name: "Secure File Transfer Protocol over SSH",
#      protocol: "sftp-ssh",
#      transport: "tcp",
#      port: 22
#    },
#    %{
#      name: "Erlang Port Mapper Daemon",
#      protocol: "epmd",
#      transport: "tcp",
#      port: 4369
#    }
#  ]

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
