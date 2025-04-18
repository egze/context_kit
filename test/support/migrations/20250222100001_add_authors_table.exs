defmodule ContextKit.Test.Repo.Migrations.AddAuthorsTable do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end
  end
end
