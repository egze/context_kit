defmodule ContextKit.CRUDBackup do
  @moduledoc """
  Provides a macro for generating common functions (`list_*`, `get_*`, `one_*`) for Ecto schemas in a context module.

  This module defines a `__using__` macro that, when used, generates a set of standard database
  interaction functions for a given schema. These functions include listing entities, getting
  individual entities by ID, and fetching a single entity based on criteria.

  ## Usage

  To use this module, add it to your context module like this:

      defmodule MyApp.Contexts.Users do
        use ContextKit,
          repo: MyApp.Repo
          schema: MyApp.Schemas.User,
          queries: MyApp.Queries.UserQuery

        # ... rest of your context module
      end

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
    # Expanding opts
    opts = Enum.map(opts, fn {key, val} -> {key, Macro.expand(val, __CALLER__)} end)

    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    queries = Keyword.fetch!(opts, :queries)

    exclude = Keyword.get(opts, :exclude, [])
    plural_resource_name = Keyword.get(opts, :plural_resource_name, nil)

    resource_name = schema |> Module.split() |> List.last() |> Macro.underscore()
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    schema_name = schema |> Module.split() |> List.last()
    # schema_singular = Macro.underscore(schema_name)
    # schema_plural = schema_name |> Inflex.pluralize() |> Macro.underscore()

    quote bind_quoted: [
            exclude: exclude,
            plural_resource_name: plural_resource_name,
            queries: queries,
            repo: repo,
            resource_name: resource_name,
            schema: schema,
            schema_name: schema_name
          ] do
      import Ecto.Changeset

      alias unquote(schema)

      unless :list in exclude do
        function_name = String.to_atom("list_#{plural_resource_name}")

        @doc """
        Returns the list of `%#{schema_name}{}`.
        Options can be passed as a keyword list or map.

        ## Examples

            iex> list_#{plural_resource_name}()
            [%#{schema_name}{}, ...]

            iex> list_#{plural_resource_name}(field: "value")
            [%#{schema_name}{}, ...]
        """
        @spec unquote(function_name)() :: [%unquote(schema){}]
        def unquote(function_name)() do
          unquote(function_name)(%{})
        end

        def unquote(function_name)(opts) when is_list(opts) or is_non_struct_map(opts) do
          query = unquote(queries).build(unquote(queries).new(), opts)

          if paginate = get_in(opts, [:paginate]) do
            paginate = if Keyword.keyword?(paginate) or is_map(paginate), do: paginate, else: []
            {unquote(repo).all(query), Paginator.new(query, paginate, repo: unquote(repo))}
          else
            unquote(repo).all(query)
          end
        end

        def unquote(function_name)(opts) when is_struct(opts, Ecto.Query) do
          unquote(repo).all(opts)
        end

        defoverridable [
          {unquote(function_name), 0},
          {unquote(function_name), 1}
        ]
      end

      unless :get in exclude do
        function_name = String.to_atom("get_#{resource_name}")
        function_name_bang = String.to_atom("get_#{resource_name}!")

        @doc """
        Returns a `%#{schema_name}{}` by id.
        Can be optionally filtered by `opts`.

        Returns `nil` if no result was found.

        ## Examples

            iex> get_#{resource_name}(id)
            %#{schema_name}{}

            iex> get_#{resource_name}(1, field: "test")
            nil
        """
        @spec unquote(function_name)(integer() | String.t()) :: %unquote(schema){}
        def unquote(function_name)(id) do
          unquote(function_name)(id, [])
        end

        @spec unquote(function_name)(integer() | String.t(), Keyword.t() | map() | Ecto.Query.t()) ::
                %unquote(schema){}
        def unquote(function_name)(id, opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          unquote(queries).new()
          |> unquote(queries).build(opts)
          |> unquote(repo).get(id)
        end

        defoverridable [
          {unquote(function_name), 1},
          {unquote(function_name), 2}
        ]

        @doc """
        Returns a `%#{schema_name}{}` by id.
        Can be optionally filtered by `opts`.

        Raises `Ecto.NoResultsError` if no result was found.

        ## Examples

            iex> get_#{resource_name}!(id)
            %#{schema_name}{}

            iex> get_#{resource_name}!(1, field: "test")
            Ecto.NoResultsError

        """
        @spec unquote(function_name)(integer() | String.t()) :: %unquote(schema){} | nil
        def unquote(function_name_bang)(id) do
          unquote(function_name_bang)(id, %{})
        end

        @spec unquote(function_name)(
                id :: integer() | String.t(),
                opts :: Keyword.t() | map() | Ecto.Query.t()
              ) ::
                %unquote(schema){} | nil
        def unquote(function_name_bang)(id, opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          unquote(queries).new()
          |> unquote(queries).build(opts)
          |> unquote(repo).get!(id)
        end

        defoverridable [
          {unquote(function_name_bang), 1},
          {unquote(function_name_bang), 2}
        ]
      end

      unless :one in exclude do
        function_name = String.to_atom("one_#{resource_name}")

        @doc """
        Fetches a single `%#{schema_name}{}` from the `opts` query via `Repo.one/2`.

        Returns nil if no result was found. Raises if more than one entry.

        ## Examples

            iex> one_#{resource_name}(opts)
            %#{unquote(schema_name)}{}

            iex> one_#{resource_name}(opts)
            nil
        """
        @spec unquote(function_name)(opts :: Keyword.t() | map() | Ecto.Query.t()) ::
                %unquote(schema){} | nil
        def unquote(function_name)(opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          unquote(queries).new()
          |> unquote(queries).build(opts)
          |> unquote(repo).one()
        end

        defoverridable [{unquote(function_name), 1}]
      end

      unless :delete in exclude do
        function_name = String.to_atom("delete_#{resource_name}")

        @doc """
        Deletes a single `%#{schema_name}{}`.

        Returns `{:ok, %#{schema_name}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{resource_name}(#{resource_name})
            {:ok, %#{schema_name}{}}
        """

        def unquote(function_name)(%unquote(schema){} = resource) do
          unquote(repo).delete(resource)
        end

        defoverridable [{unquote(function_name), 1}]
      end
    end
  end
end
