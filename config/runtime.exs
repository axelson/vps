import Config

config :vps, runtime_mode: :abc

port = Application.fetch_env!(:vps, :port)

for {app, endpoint, hostname} <- Application.fetch_env!(:vps, :endpoint_configs) do
  config app, endpoint,
    url: [host: hostname, port: port],
    hostname: hostname
end
