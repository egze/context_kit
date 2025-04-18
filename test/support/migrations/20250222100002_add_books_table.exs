defmodule ContextKit.Test.Repo.Migrations.AddBooksTable do
  use Ecto.Migration

  def change do
    create table(:books) do
      add :title, :string, null: false
      add :author_id, :integer

      timestamps()
    end

    create index(:books, [:author_id])
  end
end
