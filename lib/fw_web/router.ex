defmodule FwWeb.Router do
  use FwWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", FwWeb do
    pipe_through(:api)
  end
end
