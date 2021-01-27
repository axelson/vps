defmodule Proxy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      List.flatten([
        ProxyWeb.Telemetry,
        {Phoenix.PubSub, name: Proxy.PubSub},

        {SiteEncrypt.Phoenix, ProxyWeb.Endpoint},

        ProxyWeb.MyProxy,
      ])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Proxy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ProxyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
