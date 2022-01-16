defmodule VpsWeb.Router do
  use VpsWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", VpsWeb do
    pipe_through(:api)
  end
end
