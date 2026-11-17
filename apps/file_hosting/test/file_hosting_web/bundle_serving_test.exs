defmodule FileHostingWeb.BundleServingTest do
  use FileHostingWeb.ConnCase, async: false

  alias FileHosting.Store

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    tar =
      tarball(tmp, [
        {"index.html", "<h1>home</h1>"},
        {"app.js", "console.log(1)"},
        {"docs/index.html", "<h1>docs</h1>"},
        {"img/logo.png", <<137, 80, 78, 71>>}
      ])

    {:ok, _} = Store.publish("demo", tar)
    :ok
  end

  test "redirects the bare bundle path to add a slash, keeping the query" do
    conn = get(build_conn(), "/demo?x=1")
    assert redirected_to(conn, 301) == "/demo/?x=1"
  end

  test "serves index.html with caching and safety headers" do
    conn = get(build_conn(), "/demo/")

    assert response(conn, 200) == "<h1>home</h1>"
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert [_etag] = get_resp_header(conn, "etag")
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "serves nested files with their MIME types" do
    assert get_resp_header(get(build_conn(), "/demo/app.js"), "content-type") ==
             ["text/javascript; charset=utf-8"]

    assert get_resp_header(get(build_conn(), "/demo/img/logo.png"), "content-type") ==
             ["image/png"]
  end

  test "subdirectories redirect, then serve their index.html" do
    assert redirected_to(get(build_conn(), "/demo/docs"), 301) == "/demo/docs/"
    assert response(get(build_conn(), "/demo/docs/"), 200) == "<h1>docs</h1>"
  end

  test "answers 304 when the ETag matches, and changes the ETag on republish",
       %{tmp_dir: tmp} do
    [etag] = get_resp_header(get(build_conn(), "/demo/"), "etag")

    conn = build_conn() |> put_req_header("if-none-match", etag) |> get("/demo/")
    assert response(conn, 304) == ""

    {:ok, _} = Store.publish("demo", tarball(tmp, [{"index.html", "<h1>home</h1>"}]))
    conn = build_conn() |> put_req_header("if-none-match", etag) |> get("/demo/")
    assert response(conn, 200) == "<h1>home</h1>"
  end

  test "HEAD returns headers without a body" do
    conn = head(build_conn(), "/demo/app.js")
    assert response(conn, 200) == ""
    assert [_] = get_resp_header(conn, "etag")
  end

  test "404s for missing files, unknown bundles, the root, and traversal" do
    for path <- ["/demo/missing.js", "/nope/", "/", "/demo/%2e%2e/demo/app.js"] do
      assert response(get(build_conn(), path), 404), path
    end
  end

  test "never serves storage internals" do
    for path <- ["/meta/demo.json", "/versions/", "/staging/"] do
      assert response(get(build_conn(), path), 404), path
    end
  end
end
