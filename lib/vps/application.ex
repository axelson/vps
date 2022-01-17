defmodule Vps.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Vps.Supervisor]

    children =
      List.flatten([
        # Children for all targets
        VpsWeb.Telemetry,
        {Phoenix.PubSub, name: Vps.PubSub},
        {SiteEncrypt.Phoenix, VpsWeb.Endpoint},
        VpsWeb.MyProxy,
        children(target())
      ])

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Vps.Worker.start_link(arg)
      # {Vps.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Vps.Worker.start_link(arg)
      # {Vps.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:vps, :target)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    VpsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
