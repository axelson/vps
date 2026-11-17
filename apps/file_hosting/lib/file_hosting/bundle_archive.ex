defmodule FileHosting.BundleArchive do
  @moduledoc """
  Validates and extracts an uploaded bundle tarball (`.tar.gz`).

  The archive's table of contents is checked before anything is extracted: only
  regular files and directories, no absolute or `..` paths, a top-level
  `index.html`, and an extracted size within the limit.
  """

  @max_entries 10_000

  @type summary :: %{size_bytes: non_neg_integer(), file_count: non_neg_integer()}
  @type error :: {:error, :too_large | {:invalid, String.t()}}

  @spec extract(Path.t(), Path.t(), non_neg_integer()) :: {:ok, summary()} | error()
  def extract(tar_path, dest_dir, max_bytes) do
    with {:ok, entries} <- table(tar_path),
         {:ok, summary} <- validate(entries, max_bytes) do
      case :erl_tar.extract(to_charlist(tar_path), [:compressed, {:cwd, to_charlist(dest_dir)}]) do
        :ok -> {:ok, summary}
        {:error, reason} -> {:error, {:invalid, "extraction failed: #{format_error(reason)}"}}
      end
    end
  end

  defp table(tar_path) do
    case :erl_tar.table(to_charlist(tar_path), [:compressed, :verbose]) do
      {:ok, entries} -> {:ok, entries}
      {:error, reason} -> {:error, {:invalid, "not a valid .tar.gz: #{format_error(reason)}"}}
    end
  end

  defp validate(entries, _max_bytes) when length(entries) > @max_entries do
    {:error, {:invalid, "too many entries (max #{@max_entries})"}}
  end

  defp validate(entries, max_bytes) do
    Enum.reduce_while(entries, {:ok, %{size_bytes: 0, file_count: 0, index?: false}}, fn
      {name, type, size, _mtime, _mode, _uid, _gid}, {:ok, acc} ->
        with {:ok, path} <- normalize(to_string(name)),
             :ok <- check_type(path, type) do
          acc = add_entry(acc, path, type, size)

          if acc.size_bytes > max_bytes,
            do: {:halt, {:error, :too_large}},
            else: {:cont, {:ok, acc}}
        else
          error -> {:halt, error}
        end
    end)
    |> case do
      {:ok, %{index?: false}} -> {:error, {:invalid, "missing top-level index.html"}}
      {:ok, acc} -> {:ok, Map.delete(acc, :index?)}
      error -> error
    end
  end

  defp add_entry(acc, path, :regular, size) do
    %{
      acc
      | size_bytes: acc.size_bytes + size,
        file_count: acc.file_count + 1,
        index?: acc.index? or path == "index.html"
    }
  end

  defp add_entry(acc, _path, :directory, _size), do: acc

  # Returns the entry path relative to the bundle root, without a leading "./".
  defp normalize(name) do
    segments = name |> String.split("/") |> Enum.reject(&(&1 in ["", "."]))

    cond do
      String.starts_with?(name, "/") -> {:error, {:invalid, "absolute path: #{name}"}}
      ".." in segments -> {:error, {:invalid, "path escapes the bundle: #{name}"}}
      String.contains?(name, ["\\", <<0>>]) -> {:error, {:invalid, "invalid path: #{name}"}}
      true -> {:ok, Enum.join(segments, "/")}
    end
  end

  defp check_type(_path, type) when type in [:regular, :directory], do: :ok
  defp check_type(path, type), do: {:error, {:invalid, "unsupported entry type #{type}: #{path}"}}

  defp format_error(reason), do: reason |> :erl_tar.format_error() |> to_string()
end
