defmodule Fw.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Fw.Supervisor]

    children =
      List.flatten([
        # Children for all targets
        FwWeb.Telemetry,
        {Phoenix.PubSub, name: Fw.PubSub},
        {SiteEncrypt.Phoenix, FwWeb.Endpoint},
        FwWeb.MyFw,
        children(target())
      ])

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Fw.Worker.start_link(arg)
      # {Fw.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Fw.Worker.start_link(arg)
      # {Fw.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:fw, :target)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FwWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
