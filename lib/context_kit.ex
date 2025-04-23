defmodule ContextKit do
  @moduledoc """
  ContextKit provides a modular toolkit for building robust Phoenix/Ecto contexts with standardized CRUD operations.

  ## Overview

  ContextKit aims to reduce boilerplate code in Phoenix applications by providing:

  - Standardized CRUD operation generators
  - Dynamic query building with extensive filtering options
  - Built-in pagination support
  - Support for Phoenix 1.8 scopes
  - PubSub integration for real-time updates
  - Flexible and extensible design

  ## Basic Usage

  ContextKit offers two main modules:

  - [`ContextKit.CRUD`](ContextKit.CRUD.html) - Core CRUD operations with no scope support
  - [`ContextKit.CRUD.Scoped`](ContextKit.CRUD.Scoped.html) - CRUD operations with Phoenix 1.8 scope support and PubSub integration

  Choose the module that fits your needs:

  - Use `ContextKit.CRUD` for simple contexts like in Phoenix 1.7 without scopes or PubSub needs
  - Use `ContextKit.CRUD.Scoped` when working with Phoenix 1.8 scopes and wanting real-time updates

  ## Getting Started

  ### 1. First, define your schema modules:

  ```elixir
  defmodule MyApp.Accounts.User do
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field :email, :string
      field :name, :string
      field :status, :string

      has_many :comments, MyApp.Blog.Comment

      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :name, :status])
      |> validate_required([:email, :name])
      |> unique_constraint(:email)
    end
  end

  defmodule MyApp.Blog.Comment do
    use Ecto.Schema
    import Ecto.Changeset

    schema "comments" do
      field :body, :string
      field :status, :string

      belongs_to :user, MyApp.Accounts.User

      timestamps()
    end

    # Standard changeset for unscoped operations
    def changeset(comment, attrs) do
      comment
      |> cast(attrs, [:body, :status, :user_id])
      |> validate_required([:body, :user_id])
    end

    # Scoped changeset for Phoenix 1.8 scope operations
    def changeset(comment, attrs, scope) do
      comment
      |> cast(attrs, [:body, :status])
      |> validate_required([:body])
      |> put_change(:user_id, scope.user.id)
    end
  end
  ```

  ### 2. Create a queries module for custom query logic:

  ```elixir
  defmodule MyApp.Blog.CommentQueries do
    import Ecto.Query

    def apply_query_option({:with_recent_activity, true}, query) do
      query
      |> where([c], c.inserted_at > ago(1, "day"))
    end

    def apply_query_option({:with_user_name, name}, query) do
      query
      |> join(:inner, [c], u in assoc(c, :user))
      |> where([_, u], u.name == ^name))
    end
  end
  ```

  ### 3. Use `ContextKit.CRUD` for basic contexts:

  ```elixir
  # Basic usage without scopes
  defmodule MyApp.Blog do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Blog.Comment,
      queries: MyApp.Blog.CommentQueries
  end
  ```

  ### 4. Or use `ContextKit.CRUD.Scoped` for Phoenix 1.8 Scopes and PubSub:

  ```elixir
  defmodule MyApp.Blog do
    use ContextKit.CRUD.Scoped,
      repo: MyApp.Repo,
      schema: MyApp.Blog.Comment,
      queries: MyApp.Blog.CommentQueries,
      pubsub: MyApp.PubSub,
      scope: Application.compile_env(:my_app, :scopes)[:user]
  end
  ```

  You can define custom query functions directly in your context module by setting `queries: __MODULE__`,
  eliminating the need for a separate queries module. This is convenient for simpler contexts
  where you don't need to share query logic.

  ## Features

  ### Standard CRUD Operations

  ContextKit automatically generates common CRUD functions:

  ```elixir
  # Get query for use with Repo functions
  Blog.query_comments()
  Blog.query_comments(status: "published")

  # List records with filtering and pagination
  Blog.list_comments(status: "published", paginate: [page: 1, per_page: 20])

  # Get single record
  Blog.get_comment(123)
  Blog.get_comment!(123)  # Raises if not found

  # Get one record by criteria
  Blog.one_comment(user_id: 1)
  Blog.one_comment!(user_id: 1)  # Raises if not found

  # Save records (insert or update based on record state)
  Blog.save_comment(comment, %{body: "New or updated content"})
  Blog.save_comment!(comment, %{body: "New or updated content"})  # Raises on error

  # Create records
  Blog.create_comment(%{body: "Great post!", user_id: 1})
  Blog.create_comment!(%{body: "Great post!", user_id: 1})  # Raises on error

  # Update records
  Blog.update_comment(comment, %{body: "Updated comment"})
  Blog.update_comment!(comment, %{body: "Updated comment"})  # Raises on error

  # Get changeset
  Blog.change_comment(comment)
  Blog.change_comment(comment, %{body: "Changed comment"})

  # Delete records
  Blog.delete_comment(comment)
  Blog.delete_comment(user_id: 1, body: "Specific comment")
  ```

  ### Scoped Operations (Phoenix 1.8)

  When using `ContextKit.CRUD.Scoped`, all CRUD operations can take a scope parameter:

  ```elixir
  # Get query scoped to current user
  Blog.query_comments(socket.assigns.current_scope)
  Blog.query_comments(socket.assigns.current_scope, status: "published")

  # List comments for the current user
  Blog.list_comments(socket.assigns.current_scope)

  # Get comment by ID only if it belongs to the current user
  Blog.get_comment(socket.assigns.current_scope, 123)

  # Save comment (insert or update) with scope
  Blog.save_comment(socket.assigns.current_scope, comment, %{body: "New or updated content"})

  # Create comment for the current user
  Blog.create_comment(socket.assigns.current_scope, %{body: "Great post!"})

  # Update comment only if it belongs to the current user
  Blog.update_comment(socket.assigns.current_scope, comment, %{body: "Updated comment"})

  # Delete comment only if it belongs to the current user
  Blog.delete_comment(socket.assigns.current_scope, comment)
  ```

  ### Advanced Filtering

  Supports a wide range of filter operations:

  ```elixir
  # Basic equality
  Blog.list_comments(status: "published")

  # Complex filters
  Blog.list_comments(filters: [
    %{field: :body, op: :ilike, value: "%awesome%"},
    %{field: :status, op: :in, value: ["published", "pending"]},
    %{field: :inserted_at, op: :gt, value: ~N[2023-01-01 00:00:00]}
  ])
  ```

  All fields from the schema can be filtered on automatically.
  Any option not recognized as a field filter or standard query option is treated as a custom query option and passed to
  the queries module's `apply_query_option/2` function.

  ### Query Operations

  ContextKit provides query functions that return Ecto queries without executing them,
  useful for aggregation, composition, or further customization:

  ```elixir
  # Get a base query for all comments
  query = Blog.query_comments()

  # Apply filters to a query
  query = Blog.query_comments(status: "published")

  # Get a scoped query (with ContextKit.CRUD.Scoped)
  query = Blog.query_comments(socket.assigns.current_scope)

  # Use with Repo functions
  MyApp.Repo.aggregate(query, :count)
  MyApp.Repo.all(query)

  # Compose with other queries
  query
  |> join(:left, [c], u in assoc(c, :user))
  |> group_by([c, u], u.id)
  |> select([c, u], {u.name, count(c.id)})
  |> MyApp.Repo.all()
  ```

  Query functions return an `Ecto.Query` which is perfect for:
  - Computing aggregations (count, sum, etc.)
  - Creating complex reports with multiple joins
  - Building sub-queries
  - Performing custom operations that ContextKit's standard functions don't cover

  ### Pagination

  Built-in pagination support:

  ```elixir
  {comments, pagination} = Blog.list_comments(
    status: "published",
    paginate: [page: 2, per_page: 20]
  )

  # pagination struct includes:
  # - total_count
  # - total_pages
  # - current_page
  # - per_page
  # - has_next_page?
  # - has_previous_page?
  # - next_page
  # - previous_page
  ```

  ### PubSub Integration

  When using `ContextKit.CRUD.Scoped` with `pubsub` and `scope` options, automatic broadcasting occurs for create, update, and delete operations:

  ```elixir
  # Subscribe to scoped updates
  Blog.subscribe_comments(socket.assigns.current_scope)

  # Now the current process will receive messages like:
  # {:created, %Comment{}}
  # {:updated, %Comment{}}
  # {:deleted, %Comment{}}

  # Broadcast custom messages
  Blog.broadcast_comment(socket.assigns.current_scope, {:custom_event, comment})
  ```

  ### Custom Query Options

  Extend with custom query logic:

  ```elixir
  # In your queries module
  def apply_query_option({:with_recent_activity, true}, query) do
    query
    |> where([c], c.inserted_at > ago(1, "day"))
  end

  # Usage
  Blog.list_comments(with_recent_activity: true)
  ```

  ## Configuration Options

  When using `ContextKit.CRUD` or `ContextKit.CRUD.Scoped`, you can configure:

  - `repo`: Your Ecto repository module
  - `schema`: The Ecto schema module
  - `queries`: Module containing custom query functions
  - `except`: List of operations to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`, `:subscribe`, `:broadcast`)
  - `plural_resource_name`: Custom plural name for list functions

  Additional options for `ContextKit.CRUD.Scoped`:

  - `pubsub`: Phoenix.PubSub module for real-time features
  - `scope`: Configuration for Phoenix 1.8 scopes

  ## Best Practices

  1. Choose the right module: `ContextKit.CRUD` for simple contexts, `ContextKit.CRUD.Scoped` for contexts with scopes
  2. Create separate query modules for complex filtering logic
  3. Override generated functions when you need custom behavior
  4. Use pagination for large datasets
  5. When using scopes, implement schema-level changeset functions that accept a scope parameter
  6. Use PubSub for real-time updates in LiveView applications
  """
end
