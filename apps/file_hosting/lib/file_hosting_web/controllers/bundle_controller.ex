defmodule FileHostingWeb.BundleController do
  @moduledoc """
  Serves bundle files at `/<name>/<path>`.

  Directories serve their `index.html`, and a directory requested without a
  trailing slash (including `/<name>` itself) redirects to add one, so relative
  references resolve inside the bundle. Responses use `Cache-Control: no-cache`
  with an ETag, since bundles are replaced in place.
  """

  use Phoenix.Controller, formats: []

  import Plug.Conn

  alias FileHosting.{Name, Store}

  @utf8_types ~w(application/javascript application/json image/svg+xml)

  def show(conn, %{"name" => name, "path" => segments}) do
    version = Name.valid?(name) && Store.current_version(name)

    if version && Enum.all?(segments, &safe_segment?/1) do
      path = Path.join([Store.bundle_dir(name) | segments])

      case File.stat(path, time: :posix) do
        {:ok, %{type: :directory}} -> serve_directory(conn, version, path)
        {:ok, %{type: :regular} = stat} -> serve_file(conn, version, path, stat)
        _ -> not_found(conn, %{})
      end
    else
      not_found(conn, %{})
    end
  end

  def not_found(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp serve_directory(conn, version, dir) do
    if String.ends_with?(conn.request_path, "/") do
      index = Path.join(dir, "index.html")

      case File.stat(index, time: :posix) do
        {:ok, %{type: :regular} = stat} -> serve_file(conn, version, index, stat)
        _ -> not_found(conn, %{})
      end
    else
      query = if conn.query_string == "", do: "", else: "?" <> conn.query_string

      conn
      |> put_resp_header("location", conn.request_path <> "/" <> query)
      |> send_resp(301, "")
    end
  end

  defp serve_file(conn, version, path, stat) do
    etag = ~s("#{:erlang.phash2({version, path, stat.size, stat.mtime})}")

    conn =
      conn
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("etag", etag)
      |> put_resp_header("x-content-type-options", "nosniff")

    if etag in if_none_match(conn) do
      send_resp(conn, 304, "")
    else
      conn
      |> put_resp_header("content-type", content_type(path))
      |> send_file(200, path)
    end
  end

  defp if_none_match(conn) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
  end

  defp content_type(path) do
    type = MIME.from_path(path)

    if String.starts_with?(type, "text/") or type in @utf8_types,
      do: type <> "; charset=utf-8",
      else: type
  end

  defp safe_segment?(segment) do
    segment not in ["", ".", ".."] and not String.contains?(segment, ["/", "\\", <<0>>])
  end
end
