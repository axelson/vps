defmodule FileHostingWeb.ApiController do
  use Phoenix.Controller, formats: [:json]

  import Plug.Conn

  alias FileHosting.{Name, Store}

  def index(conn, _params) do
    json(conn, %{bundles: Enum.map(Store.list(), &with_url(conn, &1))})
  end

  def show(conn, %{"name" => name}) do
    with :ok <- validate_name(name),
         {:ok, meta} <- Store.get(name) do
      json(conn, with_url(conn, meta))
    else
      error -> error_response(conn, error)
    end
  end

  def update(conn, %{"name" => name}) do
    tar_path = Store.staging_path()

    try do
      with :ok <- validate_name(name),
           {:ok, conn} <- receive_body(conn, tar_path),
           {:ok, meta} <- Store.publish(name, tar_path) do
        json(conn, with_url(conn, meta))
      else
        error -> error_response(conn, error)
      end
    after
      File.rm(tar_path)
    end
  end

  def delete(conn, %{"name" => name}) do
    with :ok <- validate_name(name),
         :ok <- Store.delete(name) do
      send_resp(conn, 204, "")
    else
      error -> error_response(conn, error)
    end
  end

  def not_found(conn, _params), do: error_response(conn, {:error, :not_found})

  defp validate_name(name) do
    if Name.valid?(name), do: :ok, else: {:error, :invalid_name}
  end

  # Streams the request body to `path`, giving up once it exceeds the bundle cap.
  defp receive_body(conn, path) do
    File.open!(path, [:write, :binary], fn file -> stream_body(conn, file, 0) end)
  end

  defp stream_body(conn, file, received) do
    {status, chunk, conn} = read_body(conn, length: 1_000_000)
    received = received + byte_size(chunk)
    :ok = IO.binwrite(file, chunk)

    cond do
      received > Store.max_bundle_bytes() -> {:error, :too_large}
      status == :more -> stream_body(conn, file, received)
      true -> {:ok, conn}
    end
  end

  defp with_url(conn, meta), do: Map.put(meta, :url, bundle_url(conn, meta.name))

  defp bundle_url(conn, name) do
    port =
      if {conn.scheme, conn.port} in [{:http, 80}, {:https, 443}], do: "", else: ":#{conn.port}"

    "#{conn.scheme}://#{conn.host}#{port}/#{name}/"
  end

  defp error_response(conn, {:error, reason}) do
    {status, message} =
      case reason do
        :not_found -> {404, "not found"}
        :invalid_name -> {400, "invalid name: use 1-80 of a-z, 0-9 and -, not starting with -"}
        :too_large -> {413, "bundle exceeds #{Store.max_bundle_bytes()} bytes"}
        :quota_exceeded -> {507, "storage quota of #{Store.max_total_bytes()} bytes exceeded"}
        {:invalid, message} -> {422, message}
      end

    conn |> put_status(status) |> json(%{error: message})
  end
end
