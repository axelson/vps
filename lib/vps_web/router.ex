defmodule VpsWeb.Router do
  use VpsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    # plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/" do
    pipe_through :browser
    import LogViz.Router

    log_viz("/logs")
  end

  scope "/api", VpsWeb do
    pipe_through(:api)
  end
end
