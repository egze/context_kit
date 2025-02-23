defmodule ContextKit do
  @moduledoc """
  ContextKit provides a modular toolkit for building robust Phoenix/Ecto contexts with standardized CRUD operations.

  ## Overview

  ContextKit aims to reduce boilerplate code in Phoenix applications by providing:

  - Standardized CRUD operation generators
  - Dynamic query building with extensive filtering options
  - Built-in pagination support
  - Flexible and extensible design

  ## Getting Started

  1. First, define your schema module:

  ```elixir
  defmodule MyApp.Accounts.User do
    use Ecto.Schema

    schema "users" do
      field :email, :string
      field :name, :string
      field :status, :string

      timestamps()
    end
  end
  ```

  2. Create a queries module for custom query logic:

  ```elixir
  defmodule MyApp.Accounts.UserQueries do
    def apply_query_option(:with_active_posts, query) do
      query
      |> join(:inner, [u], p in assoc(u, :posts))
      |> where([_, p], p.status == "active")
    end
  end
  ```

  3. Use ContextKit.CRUD in your context:

  ```elixir
  defmodule MyApp.Accounts do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      queries: MyApp.Accounts.UserQueries
  end
  ```

  By setting `queries: __MODULE__`, you can define your custom query functions (`apply_query_option/2`) directly in your context module,
    eliminating the need for a separate queries module. This is particularly convenient for simpler contexts
    where you don't need to share query logic across multiple modules.

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

  # Delete records
  Accounts.delete_user(user)
  Accounts.delete_user(email: "user@example.com")
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

  Any option not recognized as a field filter or standard query option is treated as a custom
    query option and passed to the queries module's `apply_query_option/2` function.

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

  ### Custom Query Options

  Any option not recognized as a field filter or standard query option is treated as a custom
    query option and passed to the queries module's `apply_query_option/2` function.

  Extend with custom query logic:

  ```elixir
  # In your queries module
  def apply_query_option(:with_recent_activity, query) do
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
  - `except`: List of operations to exclude (`:list`, `:get`, `:one`, `:delete`)
  - `plural_resource_name`: Custom plural name for list functions

  ## Best Practices

  1. Create separate query modules for complex filtering logic
  2. Override generated functions when you need custom behavior
  3. Use pagination for large datasets
  4. Leverage custom query options for reusable query logic

  """
end
