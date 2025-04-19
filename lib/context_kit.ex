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

  ## Getting Started

  ### 1. First, define your schema module:

  ```elixir
  defmodule MyApp.Accounts.User do
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field :email, :string
      field :name, :string
      field :status, :string

      belongs_to :organization, MyApp.Organization

      timestamps()
    end

    # Standard changeset for unscoped operations
    def changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :name, :status, :organization_id])
      |> validate_required([:email, :name, :organization_id])
      |> unique_constraint(:email)
    end

    # Scoped changeset for Phoenix 1.8 scope operations
    def changeset(user, attrs, scope) do
      user
      |> cast(attrs, [:email, :name, :status])
      |> validate_required([:email, :name])
      |> unique_constraint(:email)
      |> put_change(:organization_id, scope.organization.id)
    end
  end
  ```

  ### 2. Create a queries module for custom query logic:

  ```elixir
  defmodule MyApp.Accounts.UserQueries do
    import Ecto.Query

    def apply_query_option({:with_active_posts, true}, query) do
      query
      |> join(:inner, [u], p in assoc(u, :posts))
      |> where([_, p], p.status == "active")
    end
  end
  ```

  ### 3. Use `ContextKit.CRUD` in your context:

  ```elixir
  # Basic usage
  defmodule MyApp.Accounts do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      queries: MyApp.Accounts.UserQueries
  end
  ```

  ### 4. With Phoenix 1.8 Scopes and PubSub:

  ```elixir
  defmodule MyApp.Accounts do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      queries: MyApp.Accounts.UserQueries,
      pubsub: MyApp.PubSub,
      scope: Application.get_env(:my_app, :scopes)[:user]
  end
  ```

  You can define custom query functions directly in your context module by setting `queries: __MODULE__`,
  eliminating the need for a separate queries module. This is convenient for simpler contexts
  where you don't need to share query logic.

  ## Features

  ### Standard CRUD Operations

  ContextKit automatically generates common CRUD functions:

  ```elixir
  # List records with filtering and pagination
  Accounts.list_users(status: "active", paginate: [page: 1, per_page: 20])

  # Get single record
  Accounts.get_user(123)
  Accounts.get_user!(123)  # Raises if not found

  # Get one record by criteria
  Accounts.one_user(email: "user@example.com")
  Accounts.one_user!(email: "user@example.com")  # Raises if not found

  # Create records
  Accounts.create_user(%{email: "new@example.com"})
  Accounts.create_user!(%{email: "new@example.com"})  # Raises on error

  # Update records
  Accounts.update_user(user, %{email: "updated@example.com"})
  Accounts.update_user!(user, %{email: "updated@example.com"})  # Raises on error

  # Get changeset
  Accounts.change_user(user)
  Accounts.change_user(user, %{email: "changed@example.com"})

  # Delete records
  Accounts.delete_user(user)
  Accounts.delete_user(email: "user@example.com")
  ```

  ### Scoped Operations (Phoenix 1.8)

  When using Phoenix 1.8 scopes, all CRUD operations take a scope parameter:

  ```elixir
  # List records in scope
  Accounts.list_users(socket.assigns.current_scope)

  # Get record in scope
  Accounts.get_user(socket.assigns.current_scope, 123)

  # Create record in scope
  Accounts.create_user(socket.assigns.current_scope, %{email: "new@example.com"})

  # Update record in scope
  Accounts.update_user(socket.assigns.current_scope, user, %{email: "updated@example.com"})

  # Delete record in scope
  Accounts.delete_user(socket.assigns.current_scope, user)
  ```

  ### Advanced Filtering

  Supports a wide range of filter operations:

  ```elixir
  # Basic equality
  Accounts.list_users(status: "active")

  # Complex filters
  Accounts.list_users(filters: [
    %{field: :email, op: :ilike, value: "@gmail.com"},
    %{field: :status, op: :in, value: ["active", "pending"]},
    %{field: :name, op: :like_or, value: ["john", "jane"]}
  ])
  ```

  All fields from the schema can be filtered on automatically.
  Any option not recognized as a field filter or standard query option is treated as a custom query option and passed to
  the queries module's `apply_query_option/2` function.

  ### Pagination

  Built-in pagination support:

  ```elixir
  {users, pagination} = Accounts.list_users(
    status: "active",
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

  When configured with `pubsub` and `scope`, automatic broadcasting occurs for create, update, and delete operations:

  ```elixir
  # Subscribe to scoped updates
  Accounts.subscribe_users(socket.assigns.current_scope)

  # Now the current process will receive messages like:
  # {:created, %User{}}
  # {:updated, %User{}}
  # {:deleted, %User{}}

  # Broadcast custom messages
  Accounts.broadcast_user(socket.assigns.current_scope, {:custom_event, user})
  ```

  ### Custom Query Options

  Extend with custom query logic:

  ```elixir
  # In your queries module
  def apply_query_option({:with_recent_activity, true}, query) do
    query
    |> where([u], u.last_active_at > ago(1, "day"))
  end

  # Usage
  Accounts.list_users(with_recent_activity: true)
  ```

  ## Configuration Options

  When using `ContextKit.CRUD`, you can configure:

  - `repo`: Your Ecto repository module
  - `schema`: The Ecto schema module
  - `queries`: Module containing custom query functions
  - `except`: List of operations to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`, `:subscribe`, `:broadcast`)
  - `plural_resource_name`: Custom plural name for list functions
  - `pubsub`: Phoenix.PubSub module for real-time features
  - `scope`: Configuration for Phoenix 1.8 scopes

  ## Best Practices

  1. Create separate query modules for complex filtering logic
  2. Override generated functions when you need custom behavior
  3. Use pagination for large datasets
  4. Leverage scopes for multi-tenant applications
  5. Implement schema-level changeset functions that accept a scope parameter
  6. Use PubSub for real-time updates in LiveView applications
  """
end
