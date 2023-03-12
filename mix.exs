defmodule Vps.MixProject do
  use Mix.Project

  @app :vps
  @version "0.1.0"
  @all_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :bbb, :osd32mp1, :x86_64, :vultr]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      archives: [nerves_bootstrap: "~> 1.10"],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      aliases: aliases(),
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Vps.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.9.0", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.8.1"},
      {:toolshed, "~> 0.2.13"},
      {:phoenix, "1.7.0-rc.2", override: true},
      {:ecto_sqlite3, "~> 0.8.2"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:bandit, ">= 0.6.8"},

      # {:site_encrypt, "~> 0.4"},
      # {:site_encrypt, path: "~/dev/forks/site_encrypt"},
      {:site_encrypt, github: "axelson/site_encrypt", branch: "support-bandit"},

      # {:main_proxy, "~> 0.2.0"},
      # {:main_proxy, path: "~/dev/forks/main_proxy"},
      # {:main_proxy, github: "axelson/main_proxy", branch: "add-telemetry"},
      {:main_proxy, github: "axelson/main_proxy", branch: "ugprade-to-1.7-redux"},
      {:exsync, github: "falood/exsync", only: :dev},

      # The sub-applications
      {:gviz, github: "axelson/dep_viz"},
      {:makeup_live, github: "axelson/makeup_live_format"},
      {:sketchpad, github: "axelson/sketchpad"},
      {:jamroom, github: "axelson/jamroom"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.13.0", targets: @all_targets},
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_x86_64, "~> 1.13", runtime: false, targets: :x86_64},
      {:nerves_system_vultr, "> 0.12.0", runtime: false, targets: :vultr}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs", "Dbgi"]],
      config_providers: [{Vps.RuntimeConfigProvider, "/data/.target.secret.exs"}]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
