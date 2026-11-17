defmodule FileHosting.Store do
  @moduledoc """
  On-disk bundle storage under the configured `:storage_dir`:

      bundles/<name>  -> ../versions/<name>.<id>   symlink; the served bundle
      versions/<name>.<id>/                         bundle files
      meta/<name>.json                              created_at, updated_at, size_bytes, file_count
      staging/                                      in-flight uploads

  Writes go through this GenServer so quota checks and swaps are serialized.
  Publishing swaps the `bundles/<name>` symlink with `rename(2)`, so readers never
  see a half-written bundle. Reads go straight to the filesystem.
  """

  use GenServer

  alias FileHosting.BundleArchive

  @default_max_bundle_bytes 25 * 1024 * 1024
  @default_max_total_bytes 1024 * 1024 * 1024

  @type meta :: %{
          name: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          size_bytes: non_neg_integer(),
          file_count: non_neg_integer()
        }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @spec root() :: Path.t()
  def root, do: Application.fetch_env!(:file_hosting, :storage_dir) |> Path.expand()

  @spec max_bundle_bytes() :: non_neg_integer()
  def max_bundle_bytes,
    do: Application.get_env(:file_hosting, :max_bundle_bytes, @default_max_bundle_bytes)

  @spec max_total_bytes() :: non_neg_integer()
  def max_total_bytes,
    do: Application.get_env(:file_hosting, :max_total_bytes, @default_max_total_bytes)

  @doc "The directory a bundle is served from (through its symlink)."
  @spec bundle_dir(String.t()) :: Path.t()
  def bundle_dir(name), do: Path.join([root(), "bundles", name])

  @doc "A fresh path in `staging/` for receiving an upload."
  @spec staging_path() :: Path.t()
  def staging_path, do: Path.join([root(), "staging", unique_id()])

  @doc "The id of the bundle's current version, or nil if the bundle doesn't exist."
  @spec current_version(String.t()) :: String.t() | nil
  def current_version(name) do
    case File.read_link(bundle_dir(name)) do
      {:ok, target} -> Path.basename(target)
      {:error, _} -> nil
    end
  end

  @spec get(String.t()) :: {:ok, meta()} | {:error, :not_found}
  def get(name) do
    with true <- current_version(name) != nil,
         {:ok, json} <- File.read(meta_path(name)) do
      {:ok, decode_meta(name, json)}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list() :: [meta()]
  def list do
    Path.join([root(), "bundles", "*"])
    |> Path.wildcard()
    |> Enum.map(&Path.basename/1)
    |> Enum.flat_map(fn name ->
      case get(name) do
        {:ok, meta} -> [meta]
        {:error, _} -> []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc "Publishes the `.tar.gz` at `tar_path` as `name`, replacing any existing bundle."
  @spec publish(String.t(), Path.t()) ::
          {:ok, meta()} | BundleArchive.error() | {:error, :quota_exceeded}
  def publish(name, tar_path), do: GenServer.call(__MODULE__, {:publish, name, tar_path}, 60_000)

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(name), do: GenServer.call(__MODULE__, {:delete, name})

  @doc "Creates the storage layout and removes leftovers from interrupted writes."
  @spec setup!() :: :ok
  def setup! do
    root = root()
    File.rm_rf!(Path.join(root, "staging"))
    for dir <- ~w(bundles versions meta staging), do: File.mkdir_p!(Path.join(root, dir))

    live = Path.join([root, "bundles", "*"]) |> Path.wildcard() |> Enum.map(&Path.basename/1)
    live_versions = live |> Enum.map(&current_version/1) |> MapSet.new()

    for version_dir <- Path.wildcard(Path.join([root, "versions", "*"])),
        Path.basename(version_dir) not in live_versions do
      File.rm_rf!(version_dir)
    end

    :ok
  end

  @impl GenServer
  def init(nil) do
    setup!()
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:publish, name, tar_path}, _from, state) do
    staging = staging_path()
    File.mkdir_p!(staging)

    result =
      with {:ok, summary} <- BundleArchive.extract(tar_path, staging, max_bundle_bytes()),
           :ok <- check_quota(name, summary.size_bytes) do
        {:ok, swap_in(name, staging, summary)}
      end

    File.rm_rf(staging)
    {:reply, result, state}
  end

  def handle_call({:delete, name}, _from, state) do
    result =
      case current_version(name) do
        nil ->
          {:error, :not_found}

        version ->
          File.rm!(bundle_dir(name))
          File.rm_rf!(version_dir(version))
          File.rm(meta_path(name))
          :ok
      end

    {:reply, result, state}
  end

  defp swap_in(name, staging, summary) do
    old_version = current_version(name)
    version = "#{name}.#{unique_id()}"
    File.rename!(staging, version_dir(version))

    # rename(2) over the existing symlink replaces it atomically
    tmp_link = staging_path()
    File.ln_s!(Path.join("../versions", version), tmp_link)
    File.rename!(tmp_link, bundle_dir(name))

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    created_at =
      case get(name) do
        {:ok, %{created_at: created_at}} -> created_at
        {:error, :not_found} -> now
      end

    meta = %{
      name: name,
      created_at: created_at,
      updated_at: now,
      size_bytes: summary.size_bytes,
      file_count: summary.file_count
    }

    write_meta!(meta)
    if old_version, do: File.rm_rf!(version_dir(old_version))
    meta
  end

  defp check_quota(name, new_bytes) do
    others = list() |> Enum.reject(&(&1.name == name)) |> Enum.map(& &1.size_bytes) |> Enum.sum()
    if others + new_bytes <= max_total_bytes(), do: :ok, else: {:error, :quota_exceeded}
  end

  defp write_meta!(meta) do
    tmp = staging_path()
    File.write!(tmp, Jason.encode_to_iodata!(Map.delete(meta, :name), pretty: true))
    File.rename!(tmp, meta_path(meta.name))
  end

  defp decode_meta(name, json) do
    data = Jason.decode!(json)

    %{
      name: name,
      created_at: data["created_at"],
      updated_at: data["updated_at"],
      size_bytes: data["size_bytes"],
      file_count: data["file_count"]
    }
  end

  defp meta_path(name), do: Path.join([root(), "meta", name <> ".json"])
  defp version_dir(version), do: Path.join([root(), "versions", version])

  defp unique_id, do: "#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
end
