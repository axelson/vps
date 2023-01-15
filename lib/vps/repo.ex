defmodule Vps.Repo do
  use Ecto.Repo, otp_app: :vps, adapter: Ecto.Adapters.SQLite3
end
