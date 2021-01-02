defmodule ProxyWeb.Router do
  use ProxyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ProxyWeb do
    pipe_through :api
  end
end
