defmodule FileHostingWeb.ApiTest do
  use FileHostingWeb.ConnCase, async: false

  @moduletag :tmp_dir

  defp upload(conn, name, tar_path) do
    conn
    |> authed()
    |> put_req_header("content-type", "application/gzip")
    |> put("/_api/bundles/#{name}", File.read!(tar_path))
  end

  describe "auth" do
    test "rejects requests without the token", %{conn: conn} do
      assert conn |> get("/_api/bundles") |> json_response(401)
      assert conn |> authed("wrong") |> get("/_api/bundles") |> json_response(401)
    end

    test "fails closed when no token is configured", %{conn: conn} do
      Application.put_env(:file_hosting, :api_token, nil)
      on_exit(fn -> Application.put_env(:file_hosting, :api_token, "test-token") end)

      assert conn |> authed("") |> get("/_api/bundles") |> json_response(401)
    end
  end

  setup do
    %{conn: build_conn()}
  end

  test "publish, show, list and delete", %{conn: conn, tmp_dir: tmp} do
    tar = tarball(tmp, [{"index.html", "<h1>hi</h1>"}])

    body = conn |> upload("2026-11-17-demo", tar) |> json_response(200)
    assert %{"name" => "2026-11-17-demo", "file_count" => 1} = body
    assert body["url"] == "http://www.example.com/2026-11-17-demo/"

    assert %{"name" => "2026-11-17-demo"} =
             build_conn()
             |> authed()
             |> get("/_api/bundles/2026-11-17-demo")
             |> json_response(200)

    assert %{"bundles" => [%{"name" => "2026-11-17-demo"}]} =
             build_conn() |> authed() |> get("/_api/bundles") |> json_response(200)

    assert build_conn() |> authed() |> delete("/_api/bundles/2026-11-17-demo") |> response(204)
    assert build_conn() |> authed() |> get("/_api/bundles/2026-11-17-demo") |> json_response(404)
  end

  test "rejects invalid names", %{conn: conn, tmp_dir: tmp} do
    tar = tarball(tmp, [{"index.html", "hi"}])

    for name <- ["_api", "Upper", "-dash", ".hidden", String.duplicate("a", 81)] do
      assert %{"error" => "invalid name" <> _} =
               build_conn() |> upload(name, tar) |> json_response(400)
    end

    assert conn |> upload("ok", tar) |> json_response(200)
  end

  test "rejects bodies over the bundle cap", %{conn: conn, tmp_dir: tmp} do
    Application.put_env(:file_hosting, :max_bundle_bytes, 10)
    tar = tarball(tmp, [{"index.html", :crypto.strong_rand_bytes(100)}])

    assert conn |> upload("big", tar) |> json_response(413)
  end

  test "reports invalid archives", %{conn: conn, tmp_dir: tmp} do
    tar = tarball(tmp, [{"page.html", "hi"}])

    assert %{"error" => "missing top-level index.html"} =
             conn |> upload("demo", tar) |> json_response(422)
  end

  test "reports quota exhaustion", %{conn: conn, tmp_dir: tmp} do
    Application.put_env(:file_hosting, :max_total_bytes, 1)
    assert conn |> upload("demo", tarball(tmp, [{"index.html", "hi"}])) |> json_response(507)
  end

  test "unknown API routes are 404 (after auth)", %{conn: conn} do
    assert conn |> authed() |> get("/_api/nope") |> json_response(404)
  end
end
