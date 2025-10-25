defmodule ContextKit.Test.Repo.Migrations.AddProfilesTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :name, :string
      add :address, :map

      timestamps()
    end
  end
end
