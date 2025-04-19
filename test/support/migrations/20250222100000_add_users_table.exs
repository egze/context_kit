defmodule ContextKit.Test.Repo.Migrations.AddUsersTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false

      timestamps()
    end
  end
end
