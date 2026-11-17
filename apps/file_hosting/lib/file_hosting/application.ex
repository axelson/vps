defmodule FileHosting.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      FileHosting.Store,
      FileHostingWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FileHosting.Supervisor)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    FileHostingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
