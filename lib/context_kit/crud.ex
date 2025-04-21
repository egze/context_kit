defmodule ContextKit.CRUD do
  @moduledoc """
  The `ContextKit.CRUD` module provides a convenient way to generate standard CRUD (Create, Read, Update, Delete)
  operations for your Ecto schemas. It reduces boilerplate code by automatically generating commonly used database
  interaction functions.

  ## Setup

  Add the following to your context module:

  ```elixir
  defmodule MyApp.Blog do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Blog.Comment,
      queries: MyApp.Blog.CommentQueries,
      except: [:delete],                    # Optional: exclude specific operations
      plural_resource_name: "comments"      # Optional: customize plural name
  end
  ```

  ## Required Options

    * `:repo` - The Ecto repository module to use for database operations
    * `:schema` - The Ecto schema module that defines your resource
    * `:queries` - Module containing query-building functions for advanced filtering

  ## Optional Options

    * `:except` - List of operation types to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`)
    * `:plural_resource_name` - Custom plural name for list functions (defaults to singular + "s")

  ## Generated Functions

  For a schema named `Comment`, the following functions are generated:

  ### List Operations
    * `list_comments/0` - Returns all comments
    * `list_comments/1` - Returns filtered comments based on options

  ### Get Operations
    * `get_comment/1` - Fetches a single comment by ID
    * `get_comment/2` - Fetches a comment by ID with additional filters
    * `get_comment!/1` - Like `get_comment/1` but raises if not found
    * `get_comment!/2` - Like `get_comment/2` but raises if not found

  ### Single Record Operations
    * `one_comment/1` - Fetches a single comment matching the criteria
    * `one_comment!/1` - Like `one_comment/1` but raises if not found

  ### Create Operations
    * `create_comment/1` - Creates a new comment with provided attributes
    * `create_comment!/1` - Like `create_comment/1` but raises on invalid attributes

  ### Update Operations
    * `update_comment/2` - Updates comment with provided attributes
    * `update_comment!/2` - Like `update_comment/2` but raises on invalid attributes

  ### Change Operations
    * `change_comment/2` - Returns a changeset for the comment with optional changes

  ### Delete Operations
    * `delete_comment/1` - Deletes a comment struct or by query criteria

  ## Query Options

  All functions that accept options support:

    * Basic filtering with field-value pairs
    * Complex queries via `Ecto.Query`
    * Pagination via `paginate: true` or `paginate: [page: 1, per_page: 20]`
    * Custom query options defined in your queries module

  ## Examples

  ```elixir
  # List all comments
  MyApp.Blog.list_comments()

  # List published comments with pagination
  MyApp.Blog.list_comments(status: :published, paginate: [page: 1])

  # Get comment by ID with preloads
  MyApp.Blog.get_comment(123, preload: [:user])

  # Create a new comment
  MyApp.Blog.create_comment(%{body: "Great post!", user_id: 1})

  # Update a comment
  MyApp.Blog.update_comment(comment, %{body: "Updated content"})

  # Get a changeset for updates
  MyApp.Blog.change_comment(comment, %{body: "Changed content"})

  # Delete comment matching criteria
  MyApp.Blog.delete_comment(body: "Specific content to delete")
  ```

  ## Queries Module

  The required `:queries` module should implement `apply_query_option/2`, which receives a query option and the current query and returns a modified query. This allows for custom filtering, sorting, and other query modifications.

  ```elixir
  defmodule MyApp.Blog.CommentQueries do
    import Ecto.Query

    def apply_query_option({:with_user_name, name}, query) do
      query
      |> join(:inner, [c], u in assoc(c, :user))
      |> where([_, u], ilike(u.name, ^"%\#{name}%"))
    end

    def apply_query_option({:recent_first, true}, query) do
      order_by(query, [c], desc: c.inserted_at)
    end

    def apply_query_option(_, query), do: query
  end
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
    resource_name = Macro.underscore(schema_name)
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    quote do
      import Ecto.Changeset
      import Ecto.Query

      alias unquote(schema)

      if :list not in unquote(except) do
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
        def unquote(:"list_#{plural_resource_name}")(opts) when is_list(opts) or is_non_struct_map(opts) do
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

      if :get not in unquote(except) do
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
        @spec unquote(:"get_#{resource_name}")(id :: term()) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(id) do
          unquote(:"get_#{resource_name}")(id, [])
        end

        @spec unquote(:"get_#{resource_name}")(
                id :: term(),
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

          unquote(repo).get(query, id)
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
        @spec unquote(:"get_#{resource_name}!")(id :: term()) :: unquote(schema).t()
        def unquote(:"get_#{resource_name}!")(id) do
          unquote(:"get_#{resource_name}!")(id, %{})
        end

        @spec unquote(:"get_#{resource_name}!")(
                id :: term(),
                opts :: Keyword.t() | map() | Ecto.Query.t()
              ) :: unquote(schema).t()
        def unquote(:"get_#{resource_name}!")(id, opts)
            when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).get!(query, id)
        end

        defoverridable [
          {unquote(:"get_#{resource_name}!"), 1},
          {unquote(:"get_#{resource_name}!"), 2}
        ]
      end

      if :one not in unquote(except) do
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
        def unquote(:"one_#{resource_name}")(opts) when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).one(query)
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
        @spec unquote(:"one_#{resource_name}!")(opts :: Keyword.t() | map() | Ecto.Query.t()) :: unquote(schema).t()
        def unquote(:"one_#{resource_name}!")(opts) when is_list(opts) or is_map(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).one!(query)
        end

        defoverridable [{unquote(:"one_#{resource_name}"), 1}]
      end

      if :delete not in unquote(except) do
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

          result = unquote(repo).one(query)

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

      if :change not in unquote(except) do
        @doc """
        Returns a `%Ecto.Changeset{}` for `%#{unquote(schema_name)}{}` by calling `#{unquote(schema_name)}.changeset/2`.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"change_#{resource_name}")(
                resource :: unquote(schema).t(),
                params :: map()
              ) :: Ecto.Changeset.t()
        def(unquote(:"change_#{resource_name}")(%unquote(schema){} = resource, params \\ %{})) do
          unquote(schema).changeset(resource, params)
        end

        defoverridable [{unquote(:"change_#{resource_name}"), 2}]
      end

      if :create not in unquote(except) do
        @doc """
        Creates a new `%#{unquote(schema_name)}{}` with provided attributes.

        ## Examples

            iex> create_#{unquote(resource_name)}(params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> create_#{unquote(resource_name)}(invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"create_#{resource_name}")(params :: map()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"create_#{resource_name}")(params \\ %{}) do
          %unquote(schema){}
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert()
        end

        @doc """
        Creates a new `%#{unquote(schema_name)}{}` with provided attributes.

        Returns the `%#{unquote(schema_name)}{}` if successful, or raises an error if not.

        ## Examples

            iex> create_#{unquote(resource_name)}!(params)
            %#{unquote(schema_name)}{}

            iex> create_#{unquote(resource_name)}!(invalid_params)
            Ecto.StaleEntryError
        """
        @spec unquote(:"create_#{resource_name}!")(params :: map()) :: unquote(schema).t()
        def unquote(:"create_#{resource_name}!")(params \\ %{}) do
          %unquote(schema){}
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert!()
        end

        defoverridable [
          {unquote(:"create_#{resource_name}"), 1},
          {unquote(:"create_#{resource_name}!"), 1}
        ]
      end

      if :update not in unquote(except) do
        @doc """
        Updates the `%#{unquote(schema_name)}{}` with provided attributes.

        ## Examples

            iex> update_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> update_#{unquote(resource_name)}(#{unquote(resource_name)}, invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"update_#{resource_name}")(
                resource :: unquote(schema).t(),
                params :: map()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"update_#{resource_name}")(resource, params \\ %{}) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).update()
        end

        @doc """
        Updates the `%#{unquote(schema_name)}{}` with provided attributes.

        Returns the `%#{unquote(schema_name)}{}` if successful, or raises an error if not.

        ## Examples

            iex> update_#{unquote(resource_name)}!(#{unquote(resource_name)}, params)
            %#{unquote(schema_name)}{}

            iex> update_#{unquote(resource_name)}!(#{unquote(resource_name)}, invalid_params)
            Ecto.StaleEntryError
        """
        @spec unquote(:"update_#{resource_name}!")(
                resource :: unquote(schema).t(),
                params :: map()
              ) :: unquote(schema).t()
        def unquote(:"update_#{resource_name}!")(resource, params \\ %{}) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).update!()
        end

        defoverridable [
          {unquote(:"update_#{resource_name}"), 2},
          {unquote(:"update_#{resource_name}!"), 2}
        ]
      end
    end
  end
end
