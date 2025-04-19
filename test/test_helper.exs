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

defmodule ContextKit.User do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :email, :string

    timestamps()
  end
end

defmodule ContextKit.Scope do
  @moduledoc false
  alias ContextKit.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end

defmodule ContextKit.Author do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "authors" do
    field :name, :string

    timestamps()

    has_many :books, ContextKit.Book
    has_many :scoped_books, ContextKit.ScopedBook
  end

  def changeset(schema, params) do
    cast(schema, params, [:name])
  end
end

defmodule ContextKit.Book do
  @moduledoc false
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

defmodule ContextKit.ScopedBook do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "scoped_books" do
    field :title, :string

    timestamps()

    belongs_to :author, ContextKit.Author
    belongs_to :user, ContextKit.User
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:title])
    |> validate_required([:title])
  end

  def changeset(schema, params, user_scope) do
    schema
    |> cast(params, [:title])
    |> put_change(:user_id, user_scope.user.id)
  end
end

defmodule ContextKit.Books do
  @moduledoc false
  use ContextKit.CRUD,
    schema: ContextKit.Book,
    repo: ContextKit.Test.Repo,
    queries: __MODULE__

  def apply_query_option({:author, author}, query) do
    where(query, [book: book], book.author_id == ^author.id)
  end
end

defmodule ContextKit.ScopedBooks do
  @moduledoc false
  use ContextKit.CRUD,
    schema: ContextKit.ScopedBook,
    repo: ContextKit.Test.Repo,
    queries: __MODULE__,
    pubsub: ContextKit.PubSub,
    scope: [
      schema_key: :user_id,
      module: ContextKit.Scope,
      access_path: [:user, :id]
    ]

  def apply_query_option({:author, author}, query) do
    where(query, [book: book], book.author_id == ^author.id)
  end
end

defmodule ContextKit.Authors do
  @moduledoc false
  use ContextKit.CRUD,
    schema: ContextKit.Author,
    repo: ContextKit.Test.Repo,
    queries: __MODULE__

  def apply_query_option({:scope, scope}, query) do
    where(query, [author: author], author.user_id == ^scope.user.id)
  end
end

Supervisor.start_link(
  [
    ContextKit.Test.Repo,
    {Phoenix.PubSub, name: ContextKit.PubSub},
    {Ecto.Migrator,
     repos: [ContextKit.Test.Repo],
     migrator: fn repo, :up, opts ->
       Ecto.Migrator.run(repo, Path.join([__DIR__, "support", "migrations"]), :up, opts)
     end}
  ],
  strategy: :one_for_one
)

ExUnit.start()
