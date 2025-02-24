Application.put_env(:context_kit, ContextKit.Test.Repo,
  database: System.get_env("SQLITE_DB") || "test.db",
  migration_lock: false
)

File.rm_rf("test.db")
File.rm_rf("test.db-shm")
File.rm_rf("test.db-wal")

defmodule ContextKit.Test.Repo do
  use Ecto.Repo, otp_app: :context_kit, adapter: Ecto.Adapters.SQLite3
end

_ = Ecto.Adapters.SQLite3.storage_up(ContextKit.Test.Repo.config())

defmodule ContextKit.Author do
  use Ecto.Schema

  import Ecto.Changeset

  schema "authors" do
    field :name, :string

    timestamps()

    has_many :books, ContextKit.Book
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:name])
  end
end

defmodule ContextKit.Book do
  use Ecto.Schema

  import Ecto.Changeset

  schema "books" do
    field :title, :string

    timestamps()

    belongs_to :author, ContextKit.Author
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:title])
    |> validate_required([:title])
  end
end

defmodule ContextKit.Books do
  use ContextKit.CRUD,
    schema: ContextKit.Book,
    repo: ContextKit.Test.Repo,
    queries: __MODULE__

  def apply_query_option({:author, author}, query) do
    where(query, [book: book], book.author_id == ^author.id)
  end
end

defmodule ContextKit.Authors do
  use ContextKit.CRUD,
    schema: ContextKit.Author,
    repo: ContextKit.Test.Repo,
    queries: __MODULE__
end

Supervisor.start_link(
  [
    ContextKit.Test.Repo,
    {Ecto.Migrator,
     repos: [ContextKit.Test.Repo],
     migrator: fn repo, :up, opts ->
       Ecto.Migrator.run(repo, Path.join([__DIR__, "support", "migrations"]), :up, opts)
     end}
  ],
  strategy: :one_for_one
)

ExUnit.start()
