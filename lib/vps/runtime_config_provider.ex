defmodule Vps.RuntimeConfigProvider do
  @behaviour Config.Provider
  # NOTE: Logger messages are not used here because they are not being reported by RingLogger

  def init(path) when is_binary(path), do: path

  def load(config, path) do
    if File.exists?(path) do
      Config.Reader.load(config, {path, []})
    else
      IO.puts("WARNING: Unable to load runtime config at #{inspect(path)}")
      config
    end
  rescue
    err ->
      IO.puts("WARNING: Unable to load runtime config due to error: #{inspect(err)}")
      config
  end
end
