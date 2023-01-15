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
        Vps.Repo,
        {SiteEncrypt.Phoenix, VpsWeb.Endpoint},
        VpsWeb.MyProxy,
        children(target()),
        Vps.StartupLogger
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

defmodule Vps.StartupLogger do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    Logger.info(
      "VPS Started up. Listening on ports #{inspect(http_port())} and #{inspect(https_port())}"
    )

    {:ok, []}
  end

  defp http_port do
    scheme_opts = Application.get_env(:main_proxy, :http, [])
    :proplists.get_value(:port, scheme_opts)
  end

  defp https_port do
    scheme_opts = Application.get_env(:main_proxy, :https, [])
    :proplists.get_value(:port, scheme_opts)
  end
end
