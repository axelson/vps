defmodule FileHosting.StorageCase do
  @moduledoc """
  Points `:storage_dir` at a fresh directory for each test and provides helpers
  for building bundle tarballs.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import FileHosting.StorageCase
    end
  end

  setup context, do: setup_storage(context)

  @doc "Requires `@moduletag :tmp_dir`."
  def setup_storage(%{tmp_dir: tmp_dir}) do
    Application.put_env(:file_hosting, :storage_dir, Path.join(tmp_dir, "storage"))
    FileHosting.Store.setup!()

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:file_hosting, :max_bundle_bytes)
      Application.delete_env(:file_hosting, :max_total_bytes)
    end)

    :ok
  end

  @doc "Builds a .tar.gz in `dir` from `[{path_in_archive, contents}]`; returns its path and bytes."
  def tarball(dir, files) do
    path = Path.join(dir, "bundle-#{System.unique_integer([:positive])}.tar.gz")
    entries = Enum.map(files, fn {name, contents} -> {to_charlist(name), contents} end)
    :ok = :erl_tar.create(to_charlist(path), entries, [:compressed])
    path
  end
end
