defmodule ContextKit.CRUD do
  @moduledoc """
  The `ContextKit.CRUD` module provides a convenient way to generate standard CRUD (Create, Read, Update, Delete) operations for your Ecto schemas. It reduces boilerplate code by automatically generating commonly used database interaction functions.

  Additionally, it supports scopes from Phoenix 1.8.

  ## Setup

  Add the following to your context module:

  ```elixir
  defmodule MyApp.Accounts do
    use ContextKit.CRUD,
      repo: MyApp.Repo,
      schema: MyApp.Accounts.User,
      queries: MyApp.Accounts.UserQueries,
      except: [:delete],                    # Optional: exclude specific operations
      plural_resource_name: "users",        # Optional: customize plural name
      pubsub: MyApp.PubSub,                 # Optional: for realtime notifications via PubSub
      scope: Application.compile_env(:my_app, :scopes)[:user] # Optional: to gain support for Phoenix 1.8 scopes.
  end
  ```

  ## Required Options

    * `:repo` - The Ecto repository module to use for database operations
    * `:schema` - The Ecto schema module that defines your resource
    * `:queries` - Module containing query-building functions for advanced filtering

  ## Optional Options

    * `:except` - List of operation types to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`, `:subscribe`, `:broadcast`)
    * `:plural_resource_name` - Custom plural name for list functions (defaults to singular + "s")
    * `:pubsub` - The Phoenix.PubSub module to use for real-time features (required for subscription features)
    * `:scope` - Configuration for scoping resources to specific contexts (e.g., organization, tenant)

  ## Generated Functions

  For a schema named `User`, the following functions are generated:

  ### List Operations
    * `list_users/0` - Returns all users
    * `list_users/1` - Returns filtered users based on options
    * `list_users/2` - Returns scoped and filtered users if `:scope` is configured

  ### Get Operations
    * `get_user/1` - Fetches a single user by ID
    * `get_user/2` - Fetches a user by ID with additional filters
    * `get_user/3` - Fetches a scoped user by ID with additional filters if `:scope` is configured
    * `get_user!/1` - Like `get_user/1` but raises if not found
    * `get_user!/2` - Like `get_user/2` but raises if not found
    * `get_user!/3` - Like `get_user/3` but raises if not found (with scope)

  ### Single Record Operations
    * `one_user/1` - Fetches a single user matching the criteria
    * `one_user/2` - Fetches a scoped single user if `:scope` is configured
    * `one_user!/1` - Like `one_user/1` but raises if not found
    * `one_user!/2` - Like `one_user/2` but raises if not found (with scope)

  ### Create Operations
    * `create_user/1` - Creates a new user with provided attributes
    * `create_user/2` - Creates a scoped user if `:scope` is configured
    * `create_user!/1` - Like `create_user/1` but raises on invalid attributes
    * `create_user!/2` - Like `create_user/2` but raises on invalid attributes (with scope)

  ### Update Operations
    * `update_user/2` - Updates user with provided attributes
    * `update_user/3` - Updates scoped user if `:scope` is configured
    * `update_user!/2` - Like `update_user/2` but raises on invalid attributes
    * `update_user!/3` - Like `update_user/3` but raises on invalid attributes (with scope)

  ### Change Operations
    * `change_user/1` - Returns a changeset for the user
    * `change_user/2` - Returns a changeset for the user with changes
    * `change_user/3` - Returns a changeset for the scoped user with changes if `:scope` is configured

  ### Delete Operations
    * `delete_user/1` - Deletes a user struct or by query criteria
    * `delete_user/2` - Deletes a scoped user if `:scope` is configured

  ### PubSub Operations (if `:pubsub` and `:scope` are configured)
    * `subscribe_users/1` - Subscribes to the scoped users topic
    * `broadcast_user/2` - Broadcasts a message to the scoped users topic

  ## Query Options

  All functions that accept options support:

    * Basic filtering with field-value pairs
    * Complex queries via `Ecto.Query`
    * Pagination via `paginate: true` or `paginate: [page: 1, per_page: 20]`
    * Custom query options defined in your queries module
    * Scoping via `scope` when using scoped functions

  ## Examples

  ```elixir
  # List all users
  MyApp.Accounts.list_users()

  # List all users with scope
  MyApp.Accounts.list_users(socket.assigns.current_scope)

  # List active users with pagination
  MyApp.Accounts.list_users(status: :active, paginate: [page: 1])

  # Get user by ID with preloads
  MyApp.Accounts.get_user(123, preload: [:posts])

  # Get user by ID with scope
  MyApp.Accounts.get_user(socket.assigns.current_scope, 123)

  # Create a new user
  MyApp.Accounts.create_user(%{email: "new@example.com"})

  # Create a new user with scope
  MyApp.Accounts.create_user(socket.assigns.current_scope, %{email: "new@example.com"})

  # Update a user
  MyApp.Accounts.update_user(user, %{email: "updated@example.com"})

  # Update a user with scope
  MyApp.Accounts.update_user(socket.assigns.current_scope, user, %{email: "updated@example.com"})

  # Get a changeset for updates
  MyApp.Accounts.change_user(user, %{email: "changed@example.com"})

  # Get a changeset for updates with scope
  MyApp.Accounts.change_user(socket.assigns.current_scope, user, %{email: "changed@example.com"})

  # Delete user
  MyApp.Accounts.delete_user(user)

  # Delete user with scope
  MyApp.Accounts.delete_user(socket.assigns.current_scope, user)

  # Delete user matching criteria
  MyApp.Accounts.delete_user(email: "user@example.com")
  ```

  Each generated function can be overridden in your context module if you need custom behavior.

  ## Queries Module

  The required `:queries` module should implement `apply_query_option/2`, which receives a query option and the current query and returns a modified query. This allows for custom filtering, sorting, and other query modifications.

  ```elixir
  defmodule MyApp.Accounts.UserQueries do
    import Ecto.Query

    def apply_query_option({:with_role, role}, query) do
      where(query, [u], u.role == ^role)
    end

    def apply_query_option({:search, term}, query) do
      where(query, [u], ilike(u.name, ^"%\#{term}%") or ilike(u.email, ^"%\#{term}%"))
    end

    def apply_query_option(_, query), do: query
  end
  ```

  ## Scope

  [Read more about scopes](https://hexdocs.pm/phoenix/1.8.0-rc.0/scopes.html).

  A scope is a data structure used to keep information about the current request or session, such as the current user logged in, the organization/company it belongs to, permissions, and so on. By using scopes, you have a single data structure that contains all relevant information, which is then passed around so all of your operations are properly scoped.

  Usually you configure it with the same scope that you use in your Phoenix application:

  ```elixir
  scope: Application.compile_env(:my_app, :scopes)[:user],
  pubsub: MyApp.PubSub # pubsub config is required for scopes
  ```

  When a scope is configured, all relevant CRUD functions take an additional scope parameter as their first argument, ensuring that operations only affect records that belong to that scope.

  ### Scope Configuration

  If you pass in the scope with `Application.compile_env(:my_app, :scopes)[:my_scope]` - it will work automatically. You can also configure the scope manually. The scope configuration should be a keyword list with the following keys:

  * `:module` - The module that defines the scope struct
  * `:access_path` - Path to access the scoping value (e.g., `[:user, :id]` for user ID)
  * `:schema_key` - The field in the schema that corresponds to the scope (e.g., `:user_id`)

  ### Subscription Example

  ```elixir
  # Subscribe to scoped updates for users
  MyApp.Accounts.subscribe_users(socket.assigns.current_scope)

  # Now the current process will receive messages like:
  # {:created, %User{}}
  # {:updated, %User{}}
  # {:deleted, %User{}}
  ```

  ### Broadcasting Example

  ```elixir
  # Broadcast the creation to all subscribers for current scope
  MyApp.Things.broadcast_thing({:something, thing}, socket.assigns.current_scope)
  ```

  Following messages are also broadcasted automatically for all create, update, delete operations:

  ```elixir
  {:created, %Thing{}}
  {:updated, %Thing{}}
  {:deleted, %Thing{}}
  ```
  """

  alias ContextKit.Paginator
  alias ContextKit.Query

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    queries = Keyword.fetch!(opts, :queries)
    scope = Keyword.get(opts, :scope)

    {scope_evaled, _} =
      if scope, do: Code.eval_quoted(scope), else: {[], nil}

    scope_module = Keyword.get(scope_evaled, :module)
    scope_access_path = Keyword.get(scope_evaled, :access_path)
    scope_schema_key = Keyword.get(scope_evaled, :schema_key)
    pubsub = Keyword.get(opts, :pubsub)
    except = Keyword.get(opts, :except, [])
    plural_resource_name = Keyword.get(opts, :plural_resource_name, nil)
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last()
    resource_name = Macro.underscore(schema_name)
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    if scope && is_nil(pubsub) do
      raise "`:pubsub` config is required, when `:scope` is configured"
    end

    quote do
      import Ecto.Changeset
      import Ecto.Query

      alias unquote(schema)

      if :subscribe not in unquote(except) do
        if unquote(scope) do
          @doc """
          Subscribes to the scoped #{unquote(schema_name)} topic via PubSub.

          ## Examples

              iex> subscribe_#{unquote(plural_resource_name)}(socket.assigns.current_scope)
              :ok

              # This subscribes to something like `user:123:#{unquote(plural_resource_name)}`, assuming
              # that `scope` is based on the `:user`.
          """
          @spec unquote(:"subscribe_#{plural_resource_name}")(scope :: unquote(scope_module).t()) ::
                  :ok | {:error, term()}
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
      end

      if :broadcast not in unquote(except) do
        if unquote(scope) do
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
        @spec unquote(:"list_#{plural_resource_name}")() :: [unquote(schema).t()]
        def unquote(:"list_#{plural_resource_name}")() do
          unquote(:"list_#{plural_resource_name}")(%{})
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
        @spec unquote(:"list_#{plural_resource_name}")(opts :: Keyword.t()) :: [
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

        @doc """
        Returns the list of `%#{unquote(schema_name)}{}`.
        Options can be passed as `%Ecto.Query{}`.

        ## Examples

            iex> list_#{unquote(plural_resource_name)}()
            [%#{unquote(schema_name)}{}, ...]

            iex> list_#{unquote(plural_resource_name)}(field: "value")
            [%#{unquote(schema_name)}{}, ...]
        """
        @spec unquote(:"list_#{plural_resource_name}")(opts :: Ecto.Query.t()) :: [
                unquote(schema).t()
              ]
        def unquote(:"list_#{plural_resource_name}")(opts) when is_struct(opts, Ecto.Query) do
          unquote(repo).all(opts)
        end

        if unquote(scope) do
          @doc """
          Returns the scoped list of `%#{unquote(schema_name)}{}`.
          Options can be passed as a keyword list.

          ## Examples

              iex> list_#{unquote(plural_resource_name)}(socket.assigns.current_scope)
              [%#{unquote(schema_name)}{}, ...]

              iex> list_#{unquote(plural_resource_name)}(socket.assigns.current_scope, field: "value")
              [%#{unquote(schema_name)}{}, ...]
          """
          def unquote(:"list_#{plural_resource_name}")(%unquote(scope_module){} = scope, opts \\ []) do
            opts = Keyword.put(opts, :scope, scope)

            unquote(:"list_#{plural_resource_name}")(opts)
          end

          defoverridable [
            {unquote(:"list_#{plural_resource_name}"), 0},
            {unquote(:"list_#{plural_resource_name}"), 1},
            {unquote(:"list_#{plural_resource_name}"), 2}
          ]
        else
          defoverridable [
            {unquote(:"list_#{plural_resource_name}"), 0},
            {unquote(:"list_#{plural_resource_name}"), 1}
          ]
        end
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
        @spec unquote(:"get_#{resource_name}")(id :: integer() | String.t()) ::
                unquote(schema).t() | nil
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
        @spec unquote(:"get_#{resource_name}")(
                id :: integer() | String.t(),
                Keyword.t() | Ecto.Query.t()
              ) ::
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

        if unquote(scope) do
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
                  id :: integer() | String.t(),
                  opts :: Keyword.t()
                ) ::
                  :ok | {:error, term()}
          def unquote(:"get_#{resource_name}")(%unquote(scope_module){} = scope, id, opts \\ []) do
            opts = Keyword.put(opts, :scope, scope)

            unquote(:"get_#{resource_name}")(id, opts)
          end

          defoverridable [
            {unquote(:"get_#{resource_name}"), 1},
            {unquote(:"get_#{resource_name}"), 2},
            {unquote(:"get_#{resource_name}"), 3}
          ]
        else
          defoverridable [
            {unquote(:"get_#{resource_name}"), 1},
            {unquote(:"get_#{resource_name}"), 2}
          ]
        end

        @doc """
        Returns a `%#{unquote(schema_name)}{}` by id.

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
                id :: integer() | String.t(),
                opts :: Keyword.t() | Ecto.Query.t()
              ) ::
                unquote(schema).t() | nil
        def unquote(:"get_#{resource_name}!")(id, opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).get!(query, id)
        end

        if unquote(scope) do
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
                  id :: integer() | String.t(),
                  opts :: Keyword.t()
                ) ::
                  :ok | {:error, term()}
          def unquote(:"get_#{resource_name}!")(%unquote(scope_module){} = scope, id, opts \\ []) do
            opts = Keyword.put(opts, :scope, scope)

            unquote(:"get_#{resource_name}!")(id, opts)
          end

          defoverridable [
            {unquote(:"get_#{resource_name}!"), 1},
            {unquote(:"get_#{resource_name}!"), 2},
            {unquote(:"get_#{resource_name}!"), 3}
          ]
        else
          defoverridable [
            {unquote(:"get_#{resource_name}!"), 1},
            {unquote(:"get_#{resource_name}!"), 2}
          ]
        end
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

        if unquote(scope) do
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
                ) ::
                  :ok | {:error, term()}
          def unquote(:"one_#{resource_name}")(%unquote(scope_module){} = scope, opts \\ []) do
            opts = Keyword.put(opts, :scope, scope)

            unquote(:"one_#{resource_name}")(opts)
          end

          defoverridable [
            {unquote(:"one_#{resource_name}"), 1},
            {unquote(:"one_#{resource_name}"), 2}
          ]
        else
          defoverridable [
            {unquote(:"one_#{resource_name}"), 1}
          ]
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
        @spec unquote(:"one_#{resource_name}!")(opts :: Keyword.t() | Ecto.Query.t()) ::
                unquote(schema).t() | nil
        def unquote(:"one_#{resource_name}!")(opts) when is_list(opts) or is_struct(opts, Ecto.Query) do
          {query, custom_query_options} =
            Query.build(Query.new(unquote(schema)), unquote(schema), opts)

          query =
            Enum.reduce(custom_query_options, query, fn query_option, query_acc ->
              apply(unquote(queries), :apply_query_option, [query_option, query_acc])
            end)

          unquote(repo).one!(query)
        end

        if unquote(scope) do
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
                ) ::
                  :ok | {:error, term()}
          def unquote(:"one_#{resource_name}!")(%unquote(scope_module){} = scope, opts \\ []) do
            opts = Keyword.put(opts, :scope, scope)

            unquote(:"one_#{resource_name}!")(opts)
          end

          defoverridable [
            {unquote(:"one_#{resource_name}!"), 1},
            {unquote(:"one_#{resource_name}!"), 2}
          ]
        else
          defoverridable [
            {unquote(:"one_#{resource_name}!"), 1}
          ]
        end
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

        if unquote(scope) do
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
        else
          defoverridable [
            {unquote(:"delete_#{resource_name}"), 1}
          ]
        end
      end

      if :change not in unquote(except) do
        @doc """
        Returns a changeset for the specified resource with the given parameters.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)})
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"change_#{resource_name}")(resource :: unquote(schema).t()) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(%unquote(schema){} = resource) do
          unquote(schema).changeset(resource, %{})
        end

        @doc """
        Returns a changeset for the specified resource with the given parameters.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"change_#{resource_name}")(
                resource :: unquote(schema).t(),
                params :: map()
              ) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(%unquote(schema){} = resource, params) when is_map(params) do
          unquote(schema).changeset(resource, params)
        end

        if unquote(scope) do
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
        else
          defoverridable [
            {unquote(:"change_#{resource_name}"), 2}
          ]
        end
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

        if unquote(scope) do
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
        else
          defoverridable [
            {unquote(:"create_#{resource_name}"), 1}
          ]
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
        def unquote(:"create_#{resource_name}!")(params) do
          %unquote(schema){}
          |> unquote(schema).changeset(params)
          |> unquote(repo).insert!()
        end

        if unquote(scope) do
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
          @spec unquote(:"create_#{resource_name}")(scope :: unquote(scope_module).t(), params :: map()) ::
                  {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
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
        else
          defoverridable [
            {unquote(:"create_#{resource_name}!"), 1}
          ]
        end
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

        if unquote(scope) do
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
        else
          defoverridable [
            {unquote(:"update_#{resource_name}"), 2}
          ]
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
              ) ::
                {:ok, unquote(schema).t()} | Ecto.Changeset.t()
        def unquote(:"update_#{resource_name}!")(resource, params) do
          resource
          |> unquote(schema).changeset(params)
          |> unquote(repo).update!()
        end

        if unquote(scope) do
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
                ) ::
                  {:ok, unquote(schema).t()} | Ecto.Changeset.t()
          def unquote(:"update_#{resource_name}!")(%unquote(scope_module){} = scope, resource, params) do
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
        else
          defoverridable [
            {unquote(:"update_#{resource_name}!"), 2}
          ]
        end
      end

      if unquote(scope) do
        @doc """
        Applies the scope to the query.
        """
        def apply_query_option({:scope, %unquote(scope_module){} = scope}, query) do
          access = Enum.map(unquote(scope_access_path), &Access.key!(&1))
          scope_value = get_in(scope, access)
          schema_access_key = unquote(scope_schema_key)

          where(query, [record], field(record, ^schema_access_key) == ^scope_value)
        end

        defoverridable [
          {:apply_query_option, 2}
        ]
      end
    end
  end
end
