defmodule ContextKit.CRUD do
  @moduledoc """
  The `ContextKit.CRUD` module generates common [CRUD](https://pl.wikipedia.org/wiki/CRUD) (Create, Read, Update, Delete) functions for a context, similar to what `mix phx.gen.context` task generates.

  ## Options

  - `:repo` - The Ecto repository module used for database operations (required)
  - `:schema` - The Ecto schema module representing the resource that these CRUD operations will be generated for (required)
  - `:queries` - The module used for constructing Ecto queries for the resource (required)
  - `:except` - A list of atoms representing the functions to be excluded from generation (optional)
  - `:plural_resource_name` - A custom plural version of the resource name to be used in function names (optional). If not provided, singular version with 's' ending will be used to generate list function

  ## Usage

  ```elixir
  defmodule MyApp.Accounts do
    use Contexted.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      exclude: [:delete],
      plural_resource_name: "users"
  end
  ```

  ## Generated Functions

  The macro generates the following functions (where `Entity` is the name of your schema):

  - `list_entities/1`: Lists all entities, optionally filtered by criteria.
  - `get_entity/2`: Gets a single entity by ID, optionally with additional query criteria.
  - `get_entity!/2`: Like `get_entity/2`, but raises an error if the entity is not found.
  - `one_entity/1`: Fetches a single entity based on the given query.

  Each of these functions can be overridden in the using module if custom behavior is needed.

  ## Options

  - `:schema`: The Ecto schema module to use (required).
  - `:queries`: A module containing query-building functions for the schema (required).

  """

  alias ContextKit.Paginator

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
          query = unquote(queries).build(unquote(queries).new(), opts)

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
          unquote(queries).new()
          |> unquote(queries).build(opts)
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
          unquote(queries).new()
          |> unquote(queries).build(opts)
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
          unquote(queries).new()
          |> unquote(queries).build(opts)
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
          unquote(queries).new()
          |> unquote(queries).build(opts)
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
          query =
            unquote(queries).new()
            |> unquote(queries).build(opts)
            |> unquote(repo).one()

          case query do
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
