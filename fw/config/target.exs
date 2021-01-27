import Config

config :logger,
  backends: [RingLogger]

config :master_proxy,
  http: [:inet6, port: 80],
  https: [:inet6, port: 443]

config :site_encrypt, sites: [{ProxyWeb.Endpoint, ProxyWeb.SiteEncryptImpl}]

config :proxy,
  cert_mode: "production",
  site_encrypt_db_folder: Path.join(~w[/data site_encrypt]),
  site_encrypt_domains: ["pham.jasonaxelson.com", "depviz.jasonaxelson.com", "makeuplive.jasonaxelson.com"],
  depviz_domain: "depviz.jasonaxelson.com",
  makeuplive_domain: "makeuplive.jasonaxelson.com"

config :proxy, ProxyWeb.Endpoint,
  url: [host: "pham.jasonaxelson.com", port: 80],
  secret_key_base: "//YcYyKOATqeqDuhCCjGuk0jpsZLR/KwcFlePCc9Cqab5WBIbkVXYk8HlTeHVLJt",
  render_errors: [view: ProxyWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Proxy.PubSub,
  live_view: [signing_salt: "B4RFj8oi"],
  server: false

config :gviz, GVizWeb.Endpoint,
  url: [host: "depviz.jasonaxelson.com", port: 443],
  hostname: "depviz.jasonaxelson.com",
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  root: Path.dirname(__DIR__),
  server: false,
  render_errors: [view: GVizWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GViz.PubSub,
  code_reloader: false

config :gviz, :phoenix_endpoint, GVizWeb.Endpoint

config :gviz, namespace: GViz

config :makeup_live, MakeupLiveWeb.Endpoint,
  url: [host: "makeuplive.jasonaxelson.com", port: 443],
  hostname: "makeuplive.jasonaxelson.com",
  check_origin: false,
  root: Path.dirname(__DIR__),
  render_errors: [view: MakeupLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MakeupLive.PubSub,
  server: false,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  live_view: [signing_salt: "NpREzhguz87xA0eEUC6IcMT2PLRDIuCw"]

config :gviz, GVizWeb.Endpoint,
  secret_key_base: "ceI+YsDLAW7ZysZivz9xpu9d+eLo/5/E9TS2bPKPmZz1PrQ7H6iF5jm2CHMU71j/"

config :makeup_live, MakeupLiveWeb.Endpoint,
  secret_key_base: "7uIEeJiHEIc8ikQb07KqrPu3cTpCiodskjUL+TdUFnfERXaGLsX4XuCjLwASbVWZ"

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
    hostname_pattern: "nerves-%s"
  ]

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

keys =
  [
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
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
