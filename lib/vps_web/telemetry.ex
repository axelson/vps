defmodule VpsWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    attach([:main_proxy, :request, :done], &__MODULE__.log_main_proxy_request/4)

    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def attach(event, fun) when is_function(fun) do
    :telemetry.attach(
      {__MODULE__, event},
      event,
      fun,
      :ok
    )
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {VpsWeb, :count_users, []}
    ]
  end

  def log_main_proxy_request(_, %{duration: duration}, metadata, _) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    plug = get_in(metadata, [:result, :plug])

    unless is_uptime_robot?(metadata) do
      Task.start(fn ->
        Vps.Repo.insert(%Vps.Hit{
          plug: inspect(plug),
          duration: duration_ms
        })
      end)
    end

    :ok
  end

  defp is_uptime_robot?(metadata) do
    user_agent = get_in(metadata, [:req, :user_agent])
    is_binary(user_agent) && String.contains?(user_agent, "uptimerobot")
  end
end
