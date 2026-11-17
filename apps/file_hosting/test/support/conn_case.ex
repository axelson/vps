defmodule FileHostingWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import FileHosting.StorageCase
      import FileHostingWeb.ConnCase

      @endpoint FileHostingWeb.Endpoint
    end
  end

  setup context, do: FileHosting.StorageCase.setup_storage(context)

  def authed(conn, token \\ "test-token"),
    do: Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)
end
