defmodule ContextKit.Test.Repo.Migrations.AddAuthorsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false

      timestamps()
    end

    create table(:scoped_authors) do
      add :name, :string, null: false

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:scoped_authors, [:user_id])
  end
end
