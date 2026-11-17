# Standalone config, used when developing or testing this app on its own. Inside
# the vps firmware, vps's own config applies instead.
import Config

config :file_hosting, FileHostingWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: FileHostingWeb.ErrorJSON], layout: false]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
