defmodule ContextKit.Test.Repo.Migrations.AddBooksTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:books) do
      add :title, :string, null: false

      add :author_id, references(:authors, on_delete: :delete_all)

      timestamps()
    end

    create index(:books, [:author_id])

    create table(:scoped_books) do
      add :title, :string, null: false

      add :scoped_author_id, references(:scoped_authors, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:scoped_books, [:scoped_author_id])
    create index(:scoped_books, [:user_id])
  end
end
