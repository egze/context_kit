defmodule ContextKit.CRUD.Scoped do
  @moduledoc """
  The `ContextKit.CRUD.Scoped` module provides a convenient way to generate standard CRUD (Create, Read, Update, Delete) operations for your Ecto schemas. It reduces boilerplate code by automatically generating commonly used database interaction functions.

  Additionally, it supports scopes from Phoenix 1.8.

  ## Setup

  Add the following to your context module:

  ```elixir
  defmodule MyApp.Blog do
    use ContextKit.CRUD.Scoped,
      repo: MyApp.Repo,
      schema: MyApp.Blog.Comment,
      queries: MyApp.Blog.CommentQueries,
      pubsub: MyApp.PubSub,                 # For realtime notifications via PubSub
      scope: Application.compile_env(:my_app, :scopes)[:user], # To gain support for Phoenix 1.8 scopes.
      except: [:delete],                    # Optional: exclude specific operations
      plural_resource_name: "comments"      # Optional: customize plural name
  end
  ```

  ## Required Options

    * `:repo` - The Ecto repository module to use for database operations
    * `:schema` - The Ecto schema module that defines your resource
    * `:queries` - Module containing query-building functions for advanced filtering
    * `:pubsub` - The Phoenix.PubSub module to use for real-time features (required for subscription features)
    * `:scope` - Configuration for scoping resources to specific contexts (e.g., user)

  ## Optional Options

    * `:except` - List of operation types to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`, `:subscribe`, `:broadcast`)
    * `:plural_resource_name` - Custom plural name for list functions (defaults to singular + "s")

  ## Generated Functions

  For a schema named `Comment`, the following functions are generated:

  ### Query Operations
    * `query_comments/0` - Returns a base query for all comments
    * `query_comments/1` - Returns a filtered query based on options (without executing)
    * `query_comments/2` - Returns a scoped and filtered query if `:scope` is configured

  ### List Operations
    * `list_comments/0` - Returns all comments
    * `list_comments/1` - Returns filtered comments based on options
    * `list_comments/2` - Returns scoped and filtered comments if `:scope` is configured

  ### Get Operations
    * `get_comment/1` - Fetches a single comment by ID
    * `get_comment/2` - Fetches a comment by ID with additional filters
    * `get_comment/3` - Fetches a scoped comment by ID with additional filters if `:scope` is configured
    * `get_comment!/1` - Like `get_comment/1` but raises if not found
    * `get_comment!/2` - Like `get_comment/2` but raises if not found
    * `get_comment!/3` - Like `get_comment/3` but raises if not found (with scope)

  ### Single Record Operations
    * `one_comment/1` - Fetches a single comment matching the criteria
    * `one_comment/2` - Fetches a scoped single comment if `:scope` is configured
    * `one_comment!/1` - Like `one_comment/1` but raises if not found
    * `one_comment!/2` - Like `one_comment/2` but raises if not found (with scope)

  ### Save Operations
    * `save_comment/1` - Saves (inserts or updates) a comment
    * `save_comment/2` - Saves a comment with the provided attributes
    * `save_comment/3` - Saves a scoped comment with attributes if `:scope` is configured
    * `save_comment!/1` - Like `save_comment/1` but raises on invalid attributes
    * `save_comment!/2` - Like `save_comment/2` but raises on invalid attributes
    * `save_comment!/3` - Like `save_comment/3` but raises on invalid attributes (with scope)

  ### Create Operations
    * `create_comment/1` - Creates a new comment with provided attributes
    * `create_comment/2` - Creates a scoped comment if `:scope` is configured
    * `create_comment!/1` - Like `create_comment/1` but raises on invalid attributes
    * `create_comment!/2` - Like `create_comment/2` but raises on invalid attributes (with scope)

  ### Update Operations
    * `update_comment/2` - Updates comment with provided attributes
    * `update_comment/3` - Updates scoped comment if `:scope` is configured
    * `update_comment!/2` - Like `update_comment/2` but raises on invalid attributes
    * `update_comment!/3` - Like `update_comment/3` but raises on invalid attributes (with scope)

  ### Change Operations
    * `change_comment/1` - Returns a changeset for the comment
    * `change_comment/2` - Returns a changeset for the comment with changes
    * `change_comment/3` - Returns a changeset for the scoped comment with changes if `:scope` is configured

  ### Delete Operations
    * `delete_comment/1` - Deletes a comment struct or by query criteria
    * `delete_comment/2` - Deletes a scoped comment if `:scope` is configured

  ### PubSub Operations (if `:pubsub` and `:scope` are configured)
    * `subscribe_comments/1` - Subscribes to the scoped comments topic
    * `broadcast_comment/2` - Broadcasts a message to the scoped comments topic

  ## Query Options

  All functions that accept options support:

    * Basic filtering with field-value pairs
    * Complex queries via `Ecto.Query`
    * Pagination via `paginate: true` or `paginate: [page: 1, per_page: 20]`
    * Custom query options defined in your queries module
    * Scoping via `scope` when using scoped functions

  ## Examples

  ```elixir
  # Get a query for comments (for use with Repo.aggregate, etc.)
  query = MyApp.Blog.query_comments(status: :published)
  MyApp.Repo.aggregate(query, :count)

  # Get a query for comments scoped to current user
  query = MyApp.Blog.query_comments(socket.assigns.current_scope)
  MyApp.Repo.aggregate(query, :count)

  # Get a query for comments scoped to current user with additional filters
  query = MyApp.Blog.query_comments(socket.assigns.current_scope, status: :published)
  MyApp.Repo.aggregate(query, :count)

  # List all comments
  MyApp.Blog.list_comments()

  # List all comments belonging to current user
  MyApp.Blog.list_comments(socket.assigns.current_scope)

  # List published comments with pagination
  MyApp.Blog.list_comments(status: :published, paginate: [page: 1])

  # Get comment by ID with preloads
  MyApp.Blog.get_comment(123, preload: [:user])

  # Get comment by ID that belongs to current user
  MyApp.Blog.get_comment(socket.assigns.current_scope, 123)

  # Save a new comment (will be inserted)
  MyApp.Blog.save_comment(%Comment{}, %{body: "Great post!", user_id: 42})

  # Save an existing comment (will be updated)
  MyApp.Blog.save_comment(existing_comment, %{body: "Updated content"})

  # Save a comment with scope (will insert or update depending on the record's state)
  MyApp.Blog.save_comment(socket.assigns.current_scope, comment, %{body: "Content"})

  # Save a comment or raise on errors
  MyApp.Blog.save_comment!(comment, %{body: "Content that must be saved"})

  # Create a new comment (manually specifying user_id)
  MyApp.Blog.create_comment(%{body: "Great post!", user_id: 42})

  # Create a new comment that automatically belongs to current user
  MyApp.Blog.create_comment(socket.assigns.current_scope, %{body: "Great post!"})

  # Update a comment
  MyApp.Blog.update_comment(comment, %{body: "Updated content"})

  # Update a comment that belongs to current user
  MyApp.Blog.update_comment(socket.assigns.current_scope, comment, %{body: "Updated content"})

  # Get a changeset for updates
  MyApp.Blog.change_comment(comment, %{body: "Changed content"})

  # Get a changeset for updates with scope
  MyApp.Blog.change_comment(socket.assigns.current_scope, comment, %{body: "Changed content"})

  # Delete comment
  MyApp.Blog.delete_comment(comment)

  # Delete comment that belongs to current user
  MyApp.Blog.delete_comment(socket.assigns.current_scope, comment)

  # Delete comment matching criteria
  MyApp.Blog.delete_comment(body: "Specific content to delete")
  ```

  Each generated function can be overridden in your context module if you need custom behavior.

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

  ## Scope

  [Read more about scopes](https://hexdocs.pm/phoenix/1.8.0-rc.0/scopes.html).

  A scope is a data structure used to keep information about the current request or session, such as the current user logged in, permissions, and so on. By using scopes, you have a single data structure that contains all relevant information, which is then passed around so all of your operations are properly scoped.

  Usually you configure it with the same scope that you use in your Phoenix application:

  ```elixir
  scope: Application.compile_env(:my_app, :scopes)[:user],
  pubsub: MyApp.PubSub # pubsub config is required for scopes
  ```

  When a scope is configured, all relevant CRUD functions take an additional scope parameter as their first argument, ensuring that operations only affect records that belong to that scope.

  For our comments example, the scope makes sure that comments are only listed, edited, or deleted by the user who created them.

  ### Scope Configuration

  If you pass in the scope with `Application.compile_env(:my_app, :scopes)[:user]` - it will work automatically. You can also configure the scope manually. The scope configuration should be a keyword list with the following keys:

  * `:module` - The module that defines the scope struct
  * `:access_path` - Path to access the scoping value (e.g., `[:user, :id]` for user ID)
  * `:schema_key` - The field in the schema that corresponds to the scope (e.g., `:user_id`)

  For our comments example, this would typically be:

  ```elixir
  scope: [
    module: MyApp.Accounts.Scope,
    access_path: [:user, :id],
    schema_key: :user_id
  ]
  ```

  ### Subscription Example

  ```elixir
  # Subscribe to comments created, updated, or deleted by the current user
  MyApp.Blog.subscribe_comments(socket.assigns.current_scope)

  # Now the current process will receive messages like:
  # {:created, %Comment{}}
  # {:updated, %Comment{}}
  # {:deleted, %Comment{}}
  ```

  ### Broadcasting Example

  ```elixir
  # Broadcast a custom message to all subscribers for current user's comments
  MyApp.Blog.broadcast_comment(socket.assigns.current_scope, {:custom_event, comment})
  ```

  Following messages are also broadcasted automatically for all create, update, delete operations:

  ```elixir
  {:created, %Comment{}}
  {:updated, %Comment{}}
  {:deleted, %Comment{}}
  ```
  """

  alias ContextKit.Paginator
  alias ContextKit.Query

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    queries = Keyword.fetch!(opts, :queries)
    scope = Keyword.fetch!(opts, :scope)
    {scope_evaled, _} = Code.eval_quoted(scope)
    scope_module = Keyword.get(scope_evaled, :module)
    scope_access_path = Keyword.get(scope_evaled, :access_path)
    scope_schema_key = Keyword.get(scope_evaled, :schema_key)
    pubsub = Keyword.fetch!(opts, :pubsub)
    except = Keyword.get(opts, :except, [])
    plural_resource_name = Keyword.get(opts, :plural_resource_name, nil)
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last()
    resource_name = Macro.underscore(schema_name)
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    quote do
      import Ecto.Changeset
      import Ecto.Query

      alias unquote(schema)
      alias unquote(scope_module)

      if :subscribe not in unquote(except) do
        @doc """
        Subscribes to the scoped #{unquote(schema_name)} topic via PubSub.

        ## Examples

            iex> subscribe_#{unquote(plural_resource_name)}(socket.assigns.current_scope)
            :ok

            # This subscribes to something like `user:123:#{unquote(plural_resource_name)}`, assuming
            # that `scope` is based on the `:user`.
        """
        @spec unquote(:"subscribe_#{plural_resource_name}")(scope :: unquote(scope_module).t()) ::
                :ok | {:error, {:already_registered, pid()}}
        def unquote(:"subscribe_#{plural_resource_name}")(%unquote(scope_module){} = scope) do
          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          key = get_in(scope, access)
          top_level_key = List.first(unquote(scope_access_path))
          pubsub_key = "#{top_level_key}:#{key}:#{unquote(plural_resource_name)}"

          Phoenix.PubSub.subscribe(
            unquote(pubsub),
            pubsub_key
          )
        end
      end

      if :broadcast not in unquote(except) do
        @doc """
          Broadcasts a message to the scoped #{unquote(schema_name)} topic via PubSub.

        ## Examples

            iex> boradcast_#{unquote(resource_name)}(socket.assigns.current_scope, {:created, #{unquote(resource_name)}})
            :ok

            # This broadcasts the message `{created, #{unquote(resource_name)}}` to the topic like `user:123:#{unquote(plural_resource_name)}`, assuming
            # that `scope` is based on the `:user`.
        """
        @spec unquote(:"broadcast_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                message :: term()
              ) ::
                :ok | {:error, term()}
        def unquote(:"broadcast_#{resource_name}")(%unquote(scope_module){} = scope, message) do
          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          key = get_in(scope, access)
          top_level_key = List.first(unquote(scope_access_path))
          pubsub_key = "#{top_level_key}:#{key}:#{unquote(plural_resource_name)}"

          Phoenix.PubSub.broadcast(
            unquote(pubsub),
            pubsub_key,
            message
          )
        end
      end

      if :query not in unquote(except) do
        @doc """
        Returns the query of `%#{unquote(schema_name)}{}`.

        Useful for passing the query into `Repo.aggregate/2`.

        ## Examples

            iex> query_#{unquote(plural_resource_name)}()
            %Ecto.Query{}

            iex> query_#{unquote(plural_resource_name)}() |> Repo.aggregate(:count)
            123
        """
        @spec unquote(:"query_#{plural_resource_name}")() :: Ecto.Query.t()
        def unquote(:"query_#{plural_resource_name}")() do
          unquote(:"query_#{plural_resource_name}")([])
        end

        @doc """
        Returns the query of `%#{unquote(schema_name)}{}`.
        Options can be passed as a keyword list or map.

        Useful for passing the query into `Repo.aggregate/2`.

        ## Examples

            iex> query_#{unquote(plural_resource_name)}(field: 123)
            %Ecto.Query{}

            iex> query_#{unquote(plural_resource_name)}(field: 123) |> Repo.aggregate(:count)
            123
        """
        @spec unquote(:"query_#{plural_resource_name}")(opts :: Keyword.t()) :: Ecto.Query.t()
        def unquote(:"query_#{plural_resource_name}")(opts) when is_list(opts) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          query
        end

        @doc """
        Returns the scoped query of `%#{unquote(schema_name)}{}`.
        Options can be passed as a keyword list or map.

        Useful for passing the query into `Repo.aggregate/2`.

        ## Examples

            iex> query_#{unquote(plural_resource_name)}(socket.assigns.current_scope, field: 123)
            %Ecto.Query{}

            iex> query_#{unquote(plural_resource_name)}(socket.assigns.current_scope, field: 123) |> Repo.aggregate(:count)
            123
        """
        @spec unquote(:"query_#{plural_resource_name}")(unquote(scope_module).t(), opts :: Keyword.t()) :: Ecto.Query.t()
        def unquote(:"query_#{plural_resource_name}")(%unquote(scope_module){} = scope, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"query_#{plural_resource_name}")(opts)
        end

        defoverridable [
          {unquote(:"query_#{plural_resource_name}"), 0},
          {unquote(:"query_#{plural_resource_name}"), 1},
          {unquote(:"query_#{plural_resource_name}"), 2}
        ]
      end

      if :list not in unquote(except) do
        @doc """
        Returns the list of `%#{unquote(schema_name)}{}`.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}()
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")() ::
                [unquote(schema).t()] | {[unquote(schema).t()], ContextKit.Paginator.t()}
        def unquote(:"list_#{plural_resource_name}")() do
          unquote(:"list_#{plural_resource_name}")([])
        end

        @doc """
        Returns the list of `%#{unquote(schema_name)}{}`.
        Options can be passed as a keyword list.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}()
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")(opts :: Keyword.t() | map()) ::
                [unquote(schema).t()] | {[unquote(schema).t()], ContextKit.Paginator.t()}
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

        @doc """
        Returns the list of `%#{unquote(schema_name)}{}`.
        Options can be passed as `%Ecto.Query{}`.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}()
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")(opts :: Ecto.Query.t()) ::
                [unquote(schema).t()] | {[unquote(schema).t()], ContextKit.Paginator.t()}
        def unquote(:"list_#{plural_resource_name}")(opts) when is_struct(opts, Ecto.Query) do
          unquote(repo).all(opts)
        end

        @doc """
        Returns the scoped list of `%#{unquote(schema_name)}{}`.
        Options can be passed as a keyword list.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}(socket.assigns.current_scope)
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(socket.assigns.current_scope, field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")(unquote(scope_module).t(), opts :: Keyword.t()) ::
                [unquote(schema).t()] | {[unquote(schema).t()], ContextKit.Paginator.t()}
        def unquote(:"list_#{plural_resource_name}")(%unquote(scope_module){} = scope, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"list_#{plural_resource_name}")(opts)
        end

        defoverridable [
          {unquote(:"list_#{plural_resource_name}"), 0},
          {unquote(:"list_#{plural_resource_name}"), 1},
          {unquote(:"list_#{plural_resource_name}"), 2}
        ]
      end

      if :get not in unquote(except) do
        @doc """
        Returns a `%#{unquote(schema_name)}{}` by id.

        Returns `nil` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}(id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}(1, field: "test")
            nil
        """
        @spec unquote(:"get_#{resource_name}")(id :: term()) :: unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(id) do
          unquote(:"get_#{resource_name}")(id, [])
        end

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
        @spec unquote(:"get_#{resource_name}")(id :: term(), opts :: Keyword.t() | Ecto.Query.t()) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(id, opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).get(query, id)
        end

        @doc """
        Returns a scoped `%#{unquote(schema_name)}{}` by id.
        Can be optionally filtered by `opts`.

        Returns `nil` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}(socket.assigns.current_scope, id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}(socket.assigns.current_scope, 1, field: "test")
            nil
        """
        @spec unquote(:"get_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                id :: term(),
                opts :: Keyword.t()
              ) :: unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}")(%unquote(scope_module){} = scope, id, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"get_#{resource_name}")(id, opts)
        end

        defoverridable [
          {unquote(:"get_#{resource_name}"), 1},
          {unquote(:"get_#{resource_name}"), 2},
          {unquote(:"get_#{resource_name}"), 3}
        ]

        @doc """
        Returns a `%#{unquote(schema_name)}{}` by id.

        Raises `Ecto.NoResultsError` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}!(id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}!(1, field: "test")
            Ecto.NoResultsError
        """
        @spec unquote(:"get_#{resource_name}!")(id :: term()) :: unquote(schema).t()
        def unquote(:"get_#{resource_name}!")(id) do
          unquote(:"get_#{resource_name}!")(id, [])
        end

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
        @spec unquote(:"get_#{resource_name}!")(
                id :: term(),
                opts :: Keyword.t() | Ecto.Query.t()
              ) :: unquote(schema).t()
        def unquote(:"get_#{resource_name}!")(id, opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).get!(query, id)
        end

        @doc """
        Returns a scoped `%#{unquote(schema_name)}{}` by id.
        Can be optionally filtered by `opts`.

        Raises `Ecto.NoResultsError` if no result was found.

        ## Examples

            iex> get_#{unquote(resource_name)}!(socket.assigns.current_scope, id)
            %#{unquote(schema_name)}{}

            iex> get_#{unquote(resource_name)}!(socket.assigns.current_scope, 1, field: "test")
            Ecto.NoResultsError
        """
        @spec unquote(:"get_#{resource_name}!")(
                scope :: unquote(scope_module).t(),
                id :: term(),
                opts :: Keyword.t()
              ) :: unquote(schema).t()
        def unquote(:"get_#{resource_name}!")(%unquote(scope_module){} = scope, id, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"get_#{resource_name}!")(id, opts)
        end

        defoverridable [
          {unquote(:"get_#{resource_name}!"), 1},
          {unquote(:"get_#{resource_name}!"), 2},
          {unquote(:"get_#{resource_name}!"), 3}
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
        @spec unquote(:"one_#{resource_name}")(opts :: Keyword.t() | Ecto.Query.t()) ::
                unquote(schema).t() | nil
        def unquote(:"one_#{resource_name}")(opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).one(query)
        end

        @doc """
        Fetches a single scoped `%#{unquote(schema_name)}{}` from the `opts` query via `Repo.one/2`.

        Returns nil if no result was found. Raises if more than one entry.

        ## Examples

            iex> one_#{unquote(resource_name)}(socket.assigns.current_scope, opts)
            %#{unquote(schema_name)}{}

            iex> one_#{unquote(resource_name)}(socket.assigns.current_scope, opts)
            nil
        """
        @spec unquote(:"one_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                opts :: Keyword.t()
              ) :: unquote(schema).t() | nil
        def unquote(:"one_#{resource_name}")(%unquote(scope_module){} = scope, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"one_#{resource_name}")(opts)
        end

        defoverridable [
          {unquote(:"one_#{resource_name}"), 1},
          {unquote(:"one_#{resource_name}"), 2}
        ]

        @doc """
        Fetches a single `%#{unquote(schema_name)}{}` from the `opts` query via `Repo.one!/2`.

        Raises `Ecto.NoResultsError` if no record was found. Raises if more than one entry.

        ## Examples

            iex> one_#{unquote(resource_name)}!(opts)
            %#{unquote(schema_name)}{}

            iex> one_#{unquote(resource_name)}!(opts)
            nil
        """
        @spec unquote(:"one_#{resource_name}!")(opts :: Keyword.t() | Ecto.Query.t()) :: unquote(schema).t()
        def unquote(:"one_#{resource_name}!")(opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).one!(query)
        end

        @doc """
        Fetches a single scoped `%#{unquote(schema_name)}{}` from the `opts` query via `Repo.one!/2`.

        Raises `Ecto.NoResultsError` if no record was found. Raises if more than one entry.

        ## Examples

            iex> one_#{unquote(resource_name)}!(socket.assigns.current_scope, opts)
            %#{unquote(schema_name)}{}

            iex> one_#{unquote(resource_name)}!(socket.assigns.current_scope, opts)
            nil
        """
        @spec unquote(:"one_#{resource_name}!")(
                scope :: unquote(scope_module).t(),
                opts :: Keyword.t()
              ) :: unquote(schema).t()
        def unquote(:"one_#{resource_name}!")(%unquote(scope_module){} = scope, opts \\ []) do
          opts = Keyword.put(opts, :scope, scope)

          unquote(:"one_#{resource_name}!")(opts)
        end

        defoverridable [
          {unquote(:"one_#{resource_name}!"), 1},
          {unquote(:"one_#{resource_name}!"), 2}
        ]
      end

      if :delete not in unquote(except) do
        @doc """
        Deletes a single `%#{unquote(schema_name)}{}` by query via `opts`.

        Returns `{:ok, %#{unquote(schema_name)}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{unquote(resource_name)}(id: 1)
            {:ok, %#{unquote(schema_name)}{}}
        """
        @spec unquote(:"delete_#{resource_name}")(opts :: Keyword.t() | map() | Ecto.Query.t()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"delete_#{resource_name}")(opts) when is_list(opts) do
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
        Deletes a single `%#{unquote(schema_name)}{}` with a scope
        and broadcasts the message `{:deleted, #{unquote(resource_name)}}`.

        Returns `{:ok, %#{unquote(schema_name)}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)})
            {:ok, %#{unquote(schema_name)}{}}
        """
        @spec unquote(:"delete_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"delete_#{resource_name}")(%unquote(scope_module){} = scope, %unquote(schema){} = resource) do
          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          scope_value = get_in(scope, access)
          schema_access_key = Access.key!(unquote(scope_schema_key))

          if get_in(resource, [schema_access_key]) != scope_value do
            raise "Record not in scope"
          end

          with {:ok, %unquote(schema){} = resource} <-
                 unquote(repo).delete(resource) do
            unquote(:"broadcast_#{resource_name}")(scope, {:deleted, resource})
            {:ok, resource}
          end
        end

        defoverridable [
          {unquote(:"delete_#{resource_name}"), 1},
          {unquote(:"delete_#{resource_name}"), 2}
        ]
      end

      if :change not in unquote(except) do
        @doc """
        Returns a changeset for the specified resource with the given parameters.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)})
            %Ecto.Changeset{}
        """
        @spec unquote(:"change_#{resource_name}")(resource :: unquote(schema).t()) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(%unquote(schema){} = resource) do
          unquote(schema).changeset(resource, %{})
        end

        @doc """
        Returns a changeset for the specified resource with the given parameters.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            %Ecto.Changeset{}
        """
        @spec unquote(:"change_#{resource_name}")(
                resource :: unquote(schema).t(),
                params :: map()
              ) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(%unquote(schema){} = resource, params) when is_map(params) do
          unquote(schema).changeset(resource, params)
        end

        @doc """
        Returns a scoped changeset for the specified resource with the given parameters.

        ## Examples

            iex> change_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)}, params)
            %Ecto.Changeset{}
        """
        @spec unquote(:"change_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t(),
                params :: map()
              ) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(
              %unquote(scope_module){} = scope,
              %unquote(schema){} = resource,
              params \\ %{}
            )
            when is_map(params) do
          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          scope_value = get_in(scope, access)
          schema_access_key = Access.key!(unquote(scope_schema_key))

          if get_in(resource, [schema_access_key]) != scope_value do
            raise "Record not in scope"
          end

          unquote(schema).changeset(resource, params, scope)
        end

        defoverridable [
          {unquote(:"change_#{resource_name}"), 2},
          {unquote(:"change_#{resource_name}"), 3}
        ]
      end

      if :save not in unquote(except) do
        @doc """
        Saves a `%#{unquote(schema_name)}{}`. Resource can be either new or persisted.

        ## Examples

            iex> save_#{unquote(resource_name)}(#{unquote(resource_name)})
            {:ok, %#{unquote(schema_name)}{}}

            iex> save_#{unquote(resource_name)}(#{unquote(resource_name)})
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"save_#{resource_name}")(resource :: unquote(schema).t()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"save_#{resource_name}")(%unquote(schema){} = resource) do
          unquote(:"save_#{resource_name}")(resource, %{})
        end

        @doc """
        Saves a `%#{unquote(schema_name)}{}` with provided attributes. Resource can be either new or persisted.

        ## Examples

            iex> save_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> save_#{unquote(resource_name)}(invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"save_#{resource_name}")(resource :: unquote(schema).t(), params :: map()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"save_#{resource_name}")(%unquote(schema){} = resource, params) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert_or_update()
        end

        @doc """
        Saves a scoped `%#{unquote(schema_name)}{}`. Resource can be either new or persisted.
        Broadcasts the message `{:created, #{unquote(resource_name)}}` or `{:updated, #{unquote(resource_name)}}`.

        ## Examples

            iex> save_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)})
            {:ok, %#{unquote(schema_name)}{}}

            iex> save_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)})
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"save_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"save_#{resource_name}")(%unquote(scope_module){} = scope, %unquote(schema){} = resource) do
          unquote(:"save_#{resource_name}")(scope, resource, %{})
        end

        @doc """
        Saves a scoped `%#{unquote(schema_name)}{}` with provided attributes. Resource can be either new or persisted.
        Broadcasts the message `{:created, #{unquote(resource_name)}}` or `{:updated, #{unquote(resource_name)}}`.

        ## Examples

            iex> save_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)}, params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> save_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)}, invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"save_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t(),
                params :: map()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"save_#{resource_name}")(%unquote(scope_module){} = scope, %unquote(schema){} = resource, params) do
          loaded? = Ecto.get_meta(resource, :state) == :loaded
          if loaded?, do: unquote(:"validate_#{resource_name}_scope!")(scope, resource)

          changeset = unquote(schema).changeset(resource, params, scope)

          with {:ok, resource} <- unquote(repo).insert_or_update(changeset) do
            if loaded?,
              do: unquote(:"broadcast_#{resource_name}")(scope, {:updated, resource}),
              else: unquote(:"broadcast_#{resource_name}")(scope, {:created, resource})

            {:ok, resource}
          end
        end

        defoverridable [
          {unquote(:"save_#{resource_name}"), 2},
          {unquote(:"save_#{resource_name}"), 3}
        ]

        @doc """
        Saves a `%#{unquote(schema_name)}{}`. Resource can be either new or persisted.

        ## Examples

            iex> save_#{unquote(resource_name)}!(#{unquote(resource_name)})
            %#{unquote(schema_name)}{}
        """
        @spec unquote(:"save_#{resource_name}!")(resource :: unquote(schema).t()) :: unquote(schema).t()
        def unquote(:"save_#{resource_name}!")(%unquote(schema){} = resource) do
          unquote(:"save_#{resource_name}!")(resource, %{})
        end

        @doc """
        Saves a `%#{unquote(schema_name)}{}` with provided attributes. Resource can be either new or persisted.

        ## Examples

            iex> save_#{unquote(resource_name)}!(#{unquote(resource_name)}, params)
            %#{unquote(schema_name)}{}
        """
        @spec unquote(:"save_#{resource_name}!")(resource :: unquote(schema).t(), params :: map()) :: unquote(schema).t()
        def unquote(:"save_#{resource_name}!")(%unquote(schema){} = resource, params) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert_or_update!()
        end

        @doc """
        Saves a scoped `%#{unquote(schema_name)}{}`. Resource can be either new or persisted.
        Broadcasts the message `{:created, #{unquote(resource_name)}}` or `{:updated, #{unquote(resource_name)}}`.

        ## Examples

            iex> save_#{unquote(resource_name)}!(socket.assigns.current_scope, #{unquote(resource_name)})
            %#{unquote(schema_name)}{}
        """
        @spec unquote(:"save_#{resource_name}!")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t()
              ) :: unquote(schema).t()
        def unquote(:"save_#{resource_name}!")(%unquote(scope_module){} = scope, %unquote(schema){} = resource) do
          unquote(:"save_#{resource_name}!")(scope, resource, %{})
        end

        @doc """
        Saves a scoped `%#{unquote(schema_name)}{}` with provided attributes. Resource can be either new or persisted.
        Broadcasts the message `{:created, #{unquote(resource_name)}}` or `{:updated, #{unquote(resource_name)}}`.

        ## Examples

            iex> save_#{unquote(resource_name)}!(socket.assigns.current_scope, #{unquote(resource_name)}, params)
            %#{unquote(schema_name)}{}
        """
        @spec unquote(:"save_#{resource_name}!")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t(),
                params :: map()
              ) :: unquote(schema).t()
        def unquote(:"save_#{resource_name}!")(%unquote(scope_module){} = scope, %unquote(schema){} = resource, params) do
          loaded? = Ecto.get_meta(resource, :state) == :loaded
          if loaded?, do: unquote(:"validate_#{resource_name}_scope!")(scope, resource)

          changeset = unquote(schema).changeset(resource, params, scope)

          with %unquote(schema){} = resource <- unquote(repo).insert_or_update!(changeset) do
            if loaded?,
              do: unquote(:"broadcast_#{resource_name}")(scope, {:updated, resource}),
              else: unquote(:"broadcast_#{resource_name}")(scope, {:created, resource})

            resource
          end
        end

        defoverridable [
          {unquote(:"save_#{resource_name}!"), 2},
          {unquote(:"save_#{resource_name}!"), 3}
        ]
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
        def unquote(:"create_#{resource_name}")(params) when is_map(params) do
          %unquote(schema){}
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert()
        end

        @doc """
        Creates a new scoped `%#{unquote(schema_name)}{}` with provided attributes
        and broadcasts the message `{:created, #{unquote(resource_name)}}`.

        ## Examples

            iex> create_#{unquote(resource_name)}(socket.assigns.current_scope, params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> create_#{unquote(resource_name)}(socket.assigns.current_scope, invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"create_#{resource_name}")(scope :: unquote(scope_module).t(), params :: map()) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"create_#{resource_name}")(%unquote(scope_module){} = scope, params) when is_map(params) do
          changeset = unquote(schema).changeset(%unquote(schema){}, params, scope)

          with {:ok, %unquote(schema){} = resource} <-
                 unquote(repo).insert(changeset) do
            unquote(:"broadcast_#{resource_name}")(scope, {:created, resource})
            {:ok, resource}
          end
        end

        defoverridable [
          {unquote(:"create_#{resource_name}"), 1},
          {unquote(:"create_#{resource_name}"), 2}
        ]

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
        def unquote(:"create_#{resource_name}!")(params) do
          %unquote(schema){}
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert!()
        end

        @doc """
        Creates a new scoped `%#{unquote(schema_name)}{}` with provided attributes
        and broadcasts the message `{:created, #{unquote(resource_name)}}`.

        Returns the `%#{unquote(schema_name)}{}` if successful, or raises an error if not.

        ## Examples

            iex> create_#{unquote(resource_name)}!(socket.assigns.current_scope, params)
            %#{unquote(schema_name)}{}

            iex> create_#{unquote(resource_name)}!(socket.assigns.current_scope, invalid_params)
            Ecto.StaleEntryError
        """
        @spec unquote(:"create_#{resource_name}!")(scope :: unquote(scope_module).t(), params :: map()) ::
                unquote(schema).t()
        def unquote(:"create_#{resource_name}!")(%unquote(scope_module){} = scope, params) when is_map(params) do
          changeset = unquote(schema).changeset(%unquote(schema){}, params, scope)

          with %unquote(schema){} = resource <-
                 unquote(repo).insert!(changeset) do
            unquote(:"broadcast_#{resource_name}")(scope, {:created, resource})
            resource
          end
        end

        defoverridable [
          {unquote(:"create_#{resource_name}!"), 1},
          {unquote(:"create_#{resource_name}!"), 2}
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
        def unquote(:"update_#{resource_name}")(%unquote(schema){} = resource, params) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).update()
        end

        @doc """
        Updates the `%#{unquote(schema_name)}{}` with provided scope and attributes
        and broadcasts the message `{:updated, #{unquote(resource_name)}}`..

        ## Examples

            iex> update_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)}, params)
            {:ok, %#{unquote(schema_name)}{}}

            iex> update_#{unquote(resource_name)}(socket.assigns.current_scope, #{unquote(resource_name)}, invalid_params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"update_#{resource_name}")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t(),
                params :: map()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"update_#{resource_name}")(%unquote(scope_module){} = scope, %unquote(schema){} = resource, params)
            when is_map(params) do
          changeset = unquote(schema).changeset(resource, params, scope)

          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          scope_value = get_in(scope, access)
          schema_access_key = Access.key!(unquote(scope_schema_key))

          if get_in(resource, [schema_access_key]) != scope_value do
            raise "Record not in scope"
          end

          with {:ok, %unquote(schema){} = resource} <-
                 unquote(repo).update(changeset) do
            unquote(:"broadcast_#{resource_name}")(scope, {:updated, resource})
            {:ok, resource}
          end
        end

        defoverridable [
          {unquote(:"update_#{resource_name}"), 2},
          {unquote(:"update_#{resource_name}"), 3}
        ]

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
        def unquote(:"update_#{resource_name}!")(%unquote(schema){} = resource, params) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).update!()
        end

        @doc """
        Updates the `%#{unquote(schema_name)}{}` with provided scope and attributes
        and broadcasts the message `{:updated, #{unquote(resource_name)}}`..

        Returns the `%#{unquote(schema_name)}{}` if successful, or raises an error if not.

        ## Examples

            iex> update_#{unquote(resource_name)}!(socket.assigns.current_scope, #{unquote(resource_name)}, params)
            %#{unquote(schema_name)}{}

            iex> update_#{unquote(resource_name)}!(socket.assigns.current_scope, #{unquote(resource_name)}, invalid_params)
            Ecto.StaleEntryError
        """
        @spec unquote(:"update_#{resource_name}!")(
                scope :: unquote(scope_module).t(),
                resource :: unquote(schema).t(),
                params :: map()
              ) :: unquote(schema).t()
        def unquote(:"update_#{resource_name}!")(%unquote(scope_module){} = scope, %unquote(schema){} = resource, params) do
          changeset = unquote(schema).changeset(resource, params, scope)

          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          scope_value = get_in(scope, access)
          schema_access_key = Access.key!(unquote(scope_schema_key))

          if get_in(resource, [schema_access_key]) != scope_value do
            raise "Record not in scope"
          end

          with %unquote(schema){} = resource <-
                 unquote(repo).update!(changeset) do
            unquote(:"broadcast_#{resource_name}")(scope, {:updated, resource})
            resource
          end
        end

        defoverridable [
          {unquote(:"update_#{resource_name}!"), 2},
          {unquote(:"update_#{resource_name}!"), 3}
        ]
      end

      @doc """
      Validates that a resource belongs to the given scope.

      This function checks if the resource is within the scope specified by the scope struct.
      It compares the resource's scope field value (e.g., `:user_id`) with the scope's value
      (e.g., the current user's ID).

      ## Parameters

        * `scope` - The scope struct that contains the authorization context
        * `resource` - The resource struct to validate against the scope

      ## Examples

          iex> validate_#{unquote(resource_name)}_scope!(socket.assigns.current_scope, comment)
          :ok

      ## Raises

        * `RuntimeError` with message "Record not in scope" if the resource does not belong to the scope
      """
      @spec unquote(:"validate_#{resource_name}_scope!")(
              scope :: unquote(scope_module).t(),
              resource :: unquote(schema).t()
            ) :: :ok
      def unquote(:"validate_#{resource_name}_scope!")(%unquote(scope_module){} = scope, %unquote(schema){} = resource) do
        access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
        scope_value = get_in(scope, access)
        schema_access_key = Access.key!(unquote(scope_schema_key))

        if get_in(resource, [schema_access_key]) != scope_value do
          raise "Record not in scope"
        end

        :ok
      end

      @doc """
      Applies the scope to the query.
      """
      def apply_query_option({:scope, %unquote(scope_module){} = scope}, query) do
        access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
        scope_value = get_in(scope, access)
        schema_access_key = unquote(scope_schema_key)

        where(query, [record], field(record, ^schema_access_key) == ^scope_value)
      end
    end
  end
end
