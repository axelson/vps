defmodule Vps.Repo.Migrations.AddHitsTable do
  use Ecto.Migration

  def change do
    create table("hits") do
      add :plug, :text
      add :duration, :integer

      timestamps(updated_at: false)
    end
  end
end
