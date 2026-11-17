import Config

config :file_hosting, FileHostingWeb.Endpoint,
  server: false,
  secret_key_base: "test-only-secret-key-base-test-only-secret-key-base-test-only-se"

# Each test points :storage_dir at its own tmp directory; this one is only used at boot.
config :file_hosting,
  storage_dir: Path.expand("../tmp/test-storage", __DIR__),
  api_token: "test-token"

config :logger, level: :warning
