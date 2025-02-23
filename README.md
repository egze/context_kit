# ContextKit

ContextKit is a modular toolkit for building robust Phoenix/Ecto contexts with standardized CRUD operations. It helps reduce boilerplate code while providing powerful querying capabilities and built-in pagination support.

## Features

- 🚀 Automatic CRUD operation generation
- 🔍 Dynamic query building with extensive filtering options
- 📄 Built-in pagination support
- 🔧 Flexible and extensible design
- 🎯 Custom query options for complex filtering

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `context_kit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:context_kit, "~> 0.1.0"}
  ]
end
```

## Quick Start

1. Define your schema:

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

2. Create a queries module (optional):

```elixir
defmodule MyApp.Accounts.UserQueries do
  def apply_query_option(:with_active_posts, query) do
    query
    |> join(:inner, [u], p in assoc(u, :posts))
    |> where([_, p], p.status == "active")
  end
end
```

3. Use ContextKit in your context:

```elixir
defmodule MyApp.Accounts do
  use ContextKit.CRUD,
    repo: MyApp.Repo,
    schema: MyApp.Accounts.User,
    queries: MyApp.Accounts.UserQueries
end
```

## Usage Examples

### Basic CRUD Operations

```elixir
# List all users
Accounts.list_users()

# List with filters and pagination
{users, pagination} = Accounts.list_users(
  status: "active",
  paginate: [page: 1, per_page: 20]
)

# Get single user
user = Accounts.get_user(123)
user = Accounts.get_user!(123)  # Raises if not found

# Get one user by criteria
user = Accounts.one_user(email: "user@example.com")

# Delete user
Accounts.delete_user(user)
Accounts.delete_user(email: "user@example.com")
```

### Advanced Filtering

```elixir
Accounts.list_users(
  filters: [
    %{field: :email, op: :ilike, value: "@gmail.com"},
    %{field: :status, op: :in, value: ["active", "pending"]},
    %{field: :name, op: :like_or, value: ["john", "jane"]}
  ]
)
```

### Custom Query Options

```elixir
# Define custom query in your queries module
def apply_query_option(:with_recent_activity, query) do
  query
  |> where([u], u.last_active_at > ago(1, "day"))
end

# Use in your context
Accounts.list_users(with_recent_activity: true)
```

## Configuration

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

## Documentation

Full documentation can be found at [https://hexdocs.pm/context_kit](https://hexdocs.pm/context_kit).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License. See LICENSE for details.
