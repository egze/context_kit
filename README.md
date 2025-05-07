# ContextKit

[![CI Status](https://github.com/egze/context_kit/actions/workflows/elixir.yml/badge.svg)](https://github.com/egze/context_kit/actions/workflows/elixir.yml)
[![Hex Version](https://img.shields.io/hexpm/v/context_kit.svg)](https://hex.pm/packages/context_kit)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/context_kit)

ContextKit is a modular toolkit for building robust Phoenix/Ecto contexts with standardized CRUD operations. It minimizes boilerplate while offering powerful querying, context scoping, and built-in pagination support.

## Installation

Add `context_kit` to your list of dependencies in `mix.exs`:

    def deps do
      [
        {:context_kit, "~> 0.3.0"}
      ]
    end

## Quick Start

### 1. Define Your Schema

Create your Ecto schemas defining the necessary fields.

```elixir
defmodule MyApp.Schemas.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    timestamps()
  end
end

defmodule MyApp.Schemas.Comment do
  use Ecto.Schema

  schema "comments" do
    field :text, :string

    belongs_to :user, MyApp.Schemas.User
    timestamps()
  end

  def changeset(comment, attrs, user_scope \\ nil) do
    changeset =
      comment
      |> cast(attrs, [:text])
      |> validate_required([:text])
      |> assoc_constraint(:user)

    if user_scope do
      put_change(changeset, :user_id, user_scope.user.id)
    else
      changeset
    end
  end
end
```

### 2. Integrate in Your Context

Use `ContextKit.CRUD.Scoped` or `ContextKit.CRUD` in your context module to hook up the schema, repository, and custom scoped queries.

- `ContextKit.CRUD.Scoped` will generate functions with and without scopes. (Requires `:pubsub` and `:scope` options).
- `ContextKit.CRUD` will generate functions only without scopes.

```elixir
defmodule MyApp.Contexts.Comments do
  use ContextKit.CRUD.Scoped,
    repo: MyApp.Repo,
    schema: MyApp.Schemas.Comment,
    queries: __MODULE__,
    pubsub: MyApp.PubSub, # For realtime notifications via PubSub.
    scope: Application.compile_env(:my_app, :scopes)[:user] # To gain support for Phoenix 1.8 scopes.
end
```

This will automatically generate the list, get, create, update, delete, and more functions in your context module. Refer to the modules below for teh exact list.

## Additional Modules Overview

- **ContextKit.CRUD**
  Provides standard CRUD operations and dynamic query building.
  Source: [crud.ex](https://github.com/egze/context_kit/blob/main/lib/context_kit/crud.ex)

- **ContextKit.CRUD.Scoped**
  Provides standard CRUD operations and dynamic query building with support of Phoenix scopes.
  Source: [scoped.ex](https://github.com/egze/context_kit/blob/main/lib/context_kit/crud/scoped.ex)

- **ContextKit.Paginator**
  Manages pagination including limit/offset calculations and metadata generation.
  Source: [paginator.ex](https://github.com/egze/context_kit/blob/main/lib/context_kit/paginator.ex)

- **ContextKit.Query**
  Enables dynamic query building with extensive filtering options.
  Source: [query.ex](https://github.com/egze/context_kit/blob/main/lib/context_kit/query.ex)

## Usage Examples

### Basic CRUD Operations

    # List all comments:
    MyApp.Contexts.Comments.list_comments()

    # List all comments using current scope:
    MyApp.Contexts.Comments.list_comments(socket.assigns.current_scope)

    # List comments with filtering and pagination:
    {comments, paginator} = MyApp.Contexts.Comments.list_comments(
      filters: [
        %{field: :text, op: :like, value: "%interesting%"}
      ],
      paginate: [page: 1, per_page: 10]
    )

    # Get a single comment (raises if not found):
    comment = MyApp.Contexts.Comments.get_comment!(456)

    # Create a new comment:
    MyApp.Contexts.Comments.create_comment(%{text: "Great post!"})

    # Update a comment:
    MyApp.Contexts.Comments.update_comment(comment, %{text: "Updated comment content"})

    # Delete a comment:
    MyApp.Contexts.Comments.delete_comment(comment)

### Advanced Filtering

Utilize flexible filters with various operators:

    MyApp.Contexts.Users.list_users(
      filters: [
        %{field: :email, op: :ilike, value: "@gmail.com"},
        %{field: :status, op: :in, value: ["active", "pending"]},
        %{field: :name, op: :like_or, value: ["john", "jane"]}
      ]
    )

### Custom Query Options

Any option not recognized as a field filter or standard query option is passed to your custom queries module’s `apply_query_option/2`.

    # Custom query option example for comments context
    MyApp.Contexts.Comments.list_comments(with_recent_activity: true)

## Documentation

Full documentation is available at [https://hexdocs.pm/context_kit](https://hexdocs.pm/context_kit).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a Pull Request

## License

MIT License. See LICENSE for details.
