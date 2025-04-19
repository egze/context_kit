defmodule ContextKit.Test.Repo.Migrations.AddAuthorsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false

      timestamps()
    end
  end
end
