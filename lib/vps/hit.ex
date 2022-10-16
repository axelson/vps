defmodule Vps.Hit do
  use Ecto.Schema

  schema "hits" do
    field :plug, :string
    field :duration, :integer

    timestamps(updated_at: false)
  end
end
