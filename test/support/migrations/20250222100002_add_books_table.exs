defmodule ContextKit.Test.Repo.Migrations.AddBooksTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:books) do
      add :title, :string, null: false
      add :author_id, :integer

      timestamps()
    end

    create index(:books, [:author_id])

    create table(:scoped_books) do
      add :title, :string, null: false
      add :author_id, :integer

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:scoped_books, [:author_id])
    create index(:scoped_books, [:user_id])
  end
end
