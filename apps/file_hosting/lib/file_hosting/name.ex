defmodule FileHosting.Name do
  @moduledoc """
  Bundle name rules: one lowercase path segment of `a-z`, `0-9` and `-`, 1–80
  characters, not starting with `-`. Names can never start with `_` or `.`, which
  keeps `/_api` reserved.
  """

  @pattern ~r/\A[a-z0-9][a-z0-9-]{0,79}\z/

  @spec valid?(term()) :: boolean()
  def valid?(name) when is_binary(name), do: Regex.match?(@pattern, name)
  def valid?(_name), do: false
end
