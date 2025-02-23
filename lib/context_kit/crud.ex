defmodule ContextKit.CRUD do
  @moduledoc """
  The `ContextKit.CRUD` module provides a convenient way to generate standard CRUD (Create, Read, Update, Delete)
  operations for your Ecto schemas. It reduces boilerplate code by automatically generating commonly used database
  interaction functions.

  ## Setup

  Add the following to your context module:

  ```elixir
  defmodule MyApp.Accounts do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      queries: MyApp.Accounts.UserQueries,
      except: [:delete],                    # Optional: exclude specific operations
      plural_resource_name: "users"         # Optional: customize plural name
  end
  ```

  ## Required Options

    * `:repo` - The Ecto repository module to use for database operations
    * `:schema` - The Ecto schema module that defines your resource
    * `:queries` - Module containing query-building functions for advanced filtering

  ## Optional Options

    * `:except` - List of operation types to exclude (`:list`, `:get`, `:one`, `:delete`)
    * `:plural_resource_name` - Custom plural name for list functions (defaults to singular + "s")

  ## Generated Functions

  For a schema named `User`, the following functions are generated:

  ### List Operations
    * `list_users/0` - Returns all users
    * `list_users/1` - Returns filtered users based on options

  ### Get Operations
    * `get_user/1` - Fetches a single user by ID
    * `get_user/2` - Fetches a user by ID with additional filters
    * `get_user!/1` - Like `get_user/1` but raises if not found
    * `get_user!/2` - Like `get_user/2` but raises if not found

  ### Single Record Operations
    * `one_user/1` - Fetches a single user matching the criteria
    * `one_user!/1` - Like `one_user/1` but raises if not found

  ### Delete Operations
    * `delete_user/1` - Deletes a user struct or by query criteria

  ## Query Options

  All functions that accept options support:

    * Basic filtering with field-value pairs
    * Complex queries via `Ecto.Query`
    * Pagination via `paginate: true` or `paginate: [page: 1, per_page: 20]`
    * Custom query options defined in your queries module

  ## Examples

  ```elixir
  # List all users
  MyApp.Accounts.list_users()

  # List active users with pagination
  MyApp.Accounts.list_users(status: :active, paginate: [page: 1])

  # Get user by ID with preloads
  MyApp.Accounts.get_user(123, preload: [:posts])

  # Delete user matching criteria
  MyApp.Accounts.delete_user(email: "user@example.com")
  ```

  Each generated function can be overridden in your context module if you need custom behavior.
  """

  alias ContextKit.Paginator
  alias ContextKit.Query

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    queries = Keyword.fetch!(opts, :queries)
    except = Keyword.get(opts, :except, [])
    plural_resource_name = Keyword.get(opts, :plural_resource_name, nil)
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last()
    resource_name = schema_name |> Macro.underscore()
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    quote do
      import Ecto.Changeset
      import Ecto.Query

      alias unquote(schema)

      unless :list in unquote(except) do
        @doc """
        Returns the list of `%#{unquote(schema_name)}{}`.
        Options can be passed as a keyword list or map.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}()
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")() :: [unquote(schema).t()]
        def unquote(:"list_#{plural_resource_name}")() do
          unquote(:"list_#{plural_resource_name}")(%{})
        end

        @spec unquote(:"list_#{plural_resource_name}")(opts :: Keyword.t() | map()) :: [
                unquote(schema).t()
              ]
        def unquote(:"list_#{plural_resource_name}")(opts)
            when is_list(opts) or is_non_struct_map(opts) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          if paginate = get_in(opts, [:paginate]) do
            paginate = if Keyword.keyword?(paginate) or is_map(paginate), do: paginate, else: []
            {unquote(repo).all(query), Paginator.new(query, paginate, repo: unquote(repo))}
          else
            unquote(repo).all(query)
          end
        end

        @spec unquote(:"list_#{plural_resource_name}")(opts :: Ecto.Query.t()) :: [
                unquote(schema).t()
              ]
        def unquote(:"list_#{plural_resource_name}")(opts) when is_struct(opts, Ecto.Query) do
          unquote(repo).all(opts)
        end

        defoverridable [
          {unquote(:"list_#{plural_resource_name}"), 0},
          {unquote(:"list_#{plural_resource_name}"), 1}
        ]
      end

      unless :get in unquote(except) do
        @doc """
        Returns a `%#{unquote(schema_name)}{}` by id.
        Can be optionally filtered by `opts`.

        Returns `nil` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}(id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}(1, field: "test")
            nil
        """
        @spec unquote(:"get_#{resource_name}")(id :: integer() | String.t()) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(id) do
          unquote(:"get_#{resource_name}")(id, [])
        end

        @spec unquote(:"get_#{resource_name}")(
                id :: integer() | String.t(),
                Keyword.t() | map() | Ecto.Query.t()
              ) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(id, opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          query
          |> unquote(repo).get(id)
        end

        defoverridable [
          {unquote(:"get_#{resource_name}"), 1},
          {unquote(:"get_#{resource_name}"), 2}
        ]

        @doc """
        Returns a `%#{unquote(schema_name)}{}` by id.
        Can be optionally filtered by `opts`.

        Raises `Ecto.NoResultsError` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}!(id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}!(1, field: "test")
            Ecto.NoResultsError

        """
        @spec unquote(:"get_#{resource_name}!")(id :: integer() | String.t()) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}!")(id) do
          unquote(:"get_#{resource_name}!")(id, %{})
        end

        @spec unquote(:"get_#{resource_name}!")(
                id :: integer() | String.t(),
                opts :: Keyword.t() | map() | Ecto.Query.t()
              ) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}!")(id, opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          query
          |> unquote(repo).get!(id)
        end

        defoverridable [
          {unquote(:"get_#{resource_name}!"), 1},
          {unquote(:"get_#{resource_name}!"), 2}
        ]
      end

      unless :one in unquote(except) do
        @doc """
        Fetches a single `%#{unquote(schema_name)}{}` from the `opts` query via `Repo.one/2`.

        Returns nil if no result was found. Raises if more than one entry.

        ## Examples

            iex> one_#{unquote(resource_name)}(opts)
            %#{unquote(schema_name)}{}

            iex> one_#{unquote(resource_name)}(opts)
            nil
        """
        @spec unquote(:"one_#{resource_name}")(opts :: Keyword.t() | map() | Ecto.Query.t()) ::
                unquote(schema).t() | nil
        def unquote(:"one_#{resource_name}")(opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          query
          |> unquote(repo).one()
        end

        @doc """
        Fetches a single `%#{unquote(schema_name)}{}` from the `opts` query via `Repo.one!/2`.

        Raises `Ecto.NoResultsError` if no record was found. Raises if more than one entry.

        ## Examples

            iex> one_#{unquote(resource_name)}!(opts)
            %#{unquote(schema_name)}{}

            iex> one_#{unquote(resource_name)}!(opts)
            nil
        """
        @spec unquote(:"one_#{resource_name}!")(opts :: Keyword.t() | map() | Ecto.Query.t()) ::
                unquote(schema).t() | nil
        def unquote(:"one_#{resource_name}!")(opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          query
          |> unquote(repo).one!()
        end

        defoverridable [{unquote(:"one_#{resource_name}"), 1}]
      end

      unless :delete in unquote(except) do
        @doc """
        Deletes a single `%#{unquote(schema_name)}{}`.

        Returns `{:ok, %#{unquote(schema_name)}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{unquote(resource_name)}(#{unquote(resource_name)})
            {:ok, %#{unquote(schema_name)}{}}
        """
        @spec unquote(:"delete_#{resource_name}")(resource :: unquote(schema).t()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"delete_#{resource_name}")(%unquote(schema){} = resource) do
          unquote(repo).delete(resource)
        end

        @doc """
        Deletes a single `%#{unquote(schema_name)}{}` by query via `opts`.

        Returns `{:ok, %#{unquote(schema_name)}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{unquote(resource_name)}(id: 1)
            {:ok, %#{unquote(schema_name)}{}}
        """
        @spec unquote(:"delete_#{resource_name}")(opts :: Keyword.t() | map() | Ecto.Query.t()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def(unquote(:"delete_#{resource_name}")(opts)) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          result =
            query
            |> unquote(repo).one()

          case result do
            nil -> {:error, :not_found}
            entity -> unquote(repo).delete(entity)
          end
        rescue
          Ecto.MultipleResultsError ->
            {:error, :multiple_entries_found}
        end

        defoverridable [{unquote(:"delete_#{resource_name}"), 1}]
      end
    end
  end
end
