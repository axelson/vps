defmodule FileHostingWeb.Router do
  use Phoenix.Router, helpers: false

  pipeline :api do
    plug FileHostingWeb.Plugs.RequireToken
  end

  scope "/_api", FileHostingWeb do
    pipe_through :api

    get "/bundles", ApiController, :index
    get "/bundles/:name", ApiController, :show
    put "/bundles/:name", ApiController, :update
    delete "/bundles/:name", ApiController, :delete
    match :*, "/*path", ApiController, :not_found
  end

  scope "/", FileHostingWeb do
    get "/:name/*path", BundleController, :show
    match :*, "/*path", BundleController, :not_found
  end
end
