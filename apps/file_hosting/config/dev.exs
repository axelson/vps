import Config

config :file_hosting, FileHostingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4010],
  server: true,
  secret_key_base: "dev-only-secret-key-base-dev-only-secret-key-base-dev-only-secret"

config :file_hosting,
  storage_dir: Path.expand("../tmp/storage", __DIR__),
  api_token: "dev-token"
