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
      pubsub: MyApp.PubSub,                 # Optional: for real-time updates
      scopes: Application.get_env(:my_app, :scopes)
  end
  ```

  ## Required Options

    * `:repo` - The Ecto repository module to use for database operations
    * `:schema` - The Ecto schema module that defines your resource
    * `:queries` - Module containing query-building functions for advanced filtering

  ## Optional Options

    * `:except` - List of operation types to exclude (`:list`, `:get`, `:one`, `:delete`, `:create`, `:update`, `:change`)
    * `:plural_resource_name` - Custom plural name for list functions (defaults to singular + "s")
    * `:pubsub` - The Phoenix.PubSub module to use for real-time features (required for subscription features)
    * `:scopes` - Map of scope configurations for subscription and broadcast features

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

  ### Create Operations
    * `create_user/1` - Creates a new user with provided attributes
    * `create_user!/1` - Like `create_user/1` but raises on invalid attributes

  ### Update Operations
    * `update_user/2` - Updates user with provided attributes
    * `update_user!/2` - Like `update_user/2` but raises on invalid attributes

  ### Change Operations
    * `change_user/2` - Returns a changeset for the user with optional changes

  ### Delete Operations
    * `delete_user/1` - Deletes a user struct or by query criteria

  ### PubSub Operations
    * `subscribe_users/1` - Subscribes to the scoped users topic
    * `broadcast_user/2` - Broadcasts a message to the scoped users topic

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

  # Create a new user
  MyApp.Accounts.create_user(%{email: "new@example.com"})

  # Update a user
  MyApp.Accounts.update_user(user, %{email: "updated@example.com"})

  # Get a changeset for updates
  MyApp.Accounts.change_user(user, %{email: "changed@example.com"})

  # Delete user matching criteria
  MyApp.Accounts.delete_user(email: "user@example.com")
  ```

  Each generated function can be overridden in your context module if you need custom behavior.

  ## Real-time Features with PubSub

  When `:pubsub` and `:scopes` are provided, ContextKit generates functions to help with real-time features via Phoenix.PubSub.

  ### Scopes

  Scopes define how to partition your real-time updates based on your application's structure. For example:

  ```elixir
  scopes: [
    tenant: [
      access_path: [:tenant, :id],
      default: true
    ],
    user: [
      access_path: [:user, :id]
    ]
  ]
  ```

  The `:access_path` defines the path to extract the scope identifier from the context, and `:default: true` marks which scope to use by default.

  ### Subscription Example

  ```elixir
  # Subscribe to tenant-scoped updates for users
  MyApp.Accounts.subscribe_users(scope: %{tenant: %{id: "tenant-123"}})

  # Now the current process will receive messages like:
  # {:created, %User{}}
  # {:updated, %User{}}
  # {:deleted, %User{}}
  ```

  ### Broadcasting Example

  ```elixir
  # Create a user
  {:ok, user} = MyApp.Accounts.create_user(%{name: "Alice"})

  # Broadcast the creation to all subscribers
  MyApp.Accounts.broadcast_user({:created, user}, scope: %{tenant: %{id: "tenant-123"}})
  ```
  """

  alias ContextKit.Paginator
  alias ContextKit.Query

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    queries = Keyword.fetch!(opts, :queries)
    scopes = Keyword.get(opts, :scopes, [])

    default_scope =
      Enum.find_value(scopes, [], fn {_key, value} ->
        if Keyword.get(value, :default), do: value
      end)

    scope_access_path = Keyword.get(default_scope, :access_path, [])
    schema_key = Keyword.get(default_scope, :schema_key)

    pubsub = Keyword.get(opts, :pubsub)
    except = Keyword.get(opts, :except, [])
    plural_resource_name = Keyword.get(opts, :plural_resource_name, nil)
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last()
    resource_name = schema_name |> Macro.underscore()
    plural_resource_name = plural_resource_name || "#{resource_name}s"

    quote do
      import Ecto.Changeset
      import Ecto.Query

      alias unquote(schema)

      unless :subscribe in unquote(except) do
        @doc """
          Subscribes to the scoped #{unquote(schema_name)} topic via PubSub.

        ## Examples

            iex> subscribe_#{unquote(plural_resource_name)}(scope: socket.assigns.current_scope)
            :ok

            # This subscribes to something like `user:123:#{unquote(plural_resource_name)}`, assuming
            # that `scope` is based on the `:user`.
        """
        @spec unquote(:"subscribe_#{plural_resource_name}")(opts :: Keyword.t()) ::
                :ok | {:error, term()}
        def unquote(:"subscribe_#{plural_resource_name}")(opts) when is_list(opts) do
          scope =
            Keyword.get(opts, :scope) ||
              raise "Missing `:scope` in #{unquote(:"subscribe_#{plural_resource_name}")} opts"

          if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

          access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
          key = get_in(scope, access)
          top_level_key = unquote(scope_access_path) |> List.first()
          pubsub_key = "#{top_level_key}:#{key}:#{unquote(plural_resource_name)}"

          Phoenix.PubSub.subscribe(
            unquote(pubsub),
            pubsub_key
          )
        end
      end

      unless :broadcast in unquote(except) do
        @doc """
          Broadcasts a message to the scoped #{unquote(schema_name)} topic via PubSub.

        ## Examples

            iex> boradcast_#{unquote(resource_name)}({:created, #{unquote(resource_name)}}, scope: socket.assigns.current_scope)
            :ok

            # This broadcasts teh message `{created, #{unquote(resource_name)}}` to the topic like `user:123:#{unquote(plural_resource_name)}`, assuming
            # that `scope` is based on the `:user`.
        """
        @spec unquote(:"broadcast_#{resource_name}")(
                message :: term(),
                opts :: Keyword.t()
              ) ::
                :ok | {:error, term()}
        def unquote(:"broadcast_#{resource_name}")(message, opts) when is_list(opts) do
          scope =
            Keyword.get(opts, :scope) ||
              raise "Missing `:scope` in #{unquote(:"broadcast_#{resource_name}")} opts"

          if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

          access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
          key = get_in(scope, access)
          top_level_key = unquote(scope_access_path) |> List.first()
          pubsub_key = "#{top_level_key}:#{key}:#{unquote(plural_resource_name)}"

          Phoenix.PubSub.broadcast(
            unquote(pubsub),
            pubsub_key,
            message
          )
        end
      end

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

        @doc """
        Deletes a single `%#{unquote(schema_name)}{}`.

        Returns `{:ok, %#{unquote(schema_name)}{}}` if successful or `{:error, changeset}` if the resource could not be deleted.

        ## Examples

            iex> delete_#{unquote(resource_name)}(#{unquote(resource_name)})
            {:ok, %#{unquote(schema_name)}{}}
        """
        @spec unquote(:"delete_#{resource_name}")(
                resource :: unquote(schema).t(),
                opts :: Keyword.t()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"delete_#{resource_name}")(%unquote(schema){} = resource, opts \\ [])
            when is_list(opts) do
          has_scope? = Keyword.has_key?(opts, :scope)

          if has_scope? do
            if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)
            access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
            key = get_in(scope, access)
            schema_key = Access.key!(unquote(schema_key))

            if get_in(resource, [schema_key]) != key do
              raise "Record not in scope"
            end

            with {:ok, resource = %unquote(schema){}} <-
                   unquote(repo).delete(resource) do
              unquote(:"broadcast_#{resource_name}")({:deleted, resource}, scope: scope)
              {:ok, resource}
            end
          else
            unquote(repo).delete(resource)
          end
        end

        defoverridable [{unquote(:"delete_#{resource_name}"), 1}]
        defoverridable [{unquote(:"delete_#{resource_name}"), 2}]
      end

      unless :change in unquote(except) do
        @doc """
        Returns a `%Ecto.Changeset{}` for `%#{unquote(schema_name)}{}` by calling `#{unquote(schema_name)}.changeset/2`.

        ## Examples

            iex> change_#{unquote(resource_name)}(#{unquote(resource_name)}, params)
            {:ok, %Ecto.Changeset{}}
        """
        @spec unquote(:"change_#{resource_name}")(
                resource :: unquote(schema).t(),
                opts :: Keyword.t()
              ) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(
              %unquote(schema){} = resource,
              opts
            )
            when is_list(opts) do
          changeset =
            resource
            |> unquote(schema).changeset(%{})

          has_scope? = Keyword.has_key?(opts, :scope)

          if has_scope? do
            if !unquote(pubsub),
              do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)
            access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
            key = get_in(scope, access)
            schema_key = Access.key!(unquote(schema_key))

            if get_in(resource, [schema_key]) != key do
              raise "Record not in scope"
            end

            changeset
          else
            changeset
          end
        end

        @spec unquote(:"change_#{resource_name}")(
                resource :: unquote(schema).t(),
                params :: map(),
                opts :: Keyword.t()
              ) :: Ecto.Changeset.t()
        def unquote(:"change_#{resource_name}")(
              %unquote(schema){} = resource,
              params \\ %{},
              opts \\ []
            )
            when is_map(params) and
                   is_list(opts) do
          changeset =
            resource
            |> unquote(schema).changeset(params)

          has_scope? = Keyword.has_key?(opts, :scope)

          if has_scope? do
            if !unquote(pubsub),
              do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)
            access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
            key = get_in(scope, access)
            schema_key = Access.key!(unquote(schema_key))

            if get_in(resource, [schema_key]) != key do
              raise "Record not in scope"
            end

            changeset
          else
            changeset
          end
        end

        defoverridable [{unquote(:"change_#{resource_name}"), 2}]
      end

      unless :create in unquote(except) do
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
        def unquote(:"create_#{resource_name}")(params, opts \\ []) do
          has_scope? = Keyword.has_key?(opts, :scope)

          changeset =
            %unquote(schema){}
            |> unquote(schema).changeset(params)

          if has_scope? do
            if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)

            with {:ok, resource = %unquote(schema){}} <-
                   unquote(repo).insert(changeset) do
              unquote(:"broadcast_#{resource_name}")({:created, resource}, scope: scope)
              {:ok, resource}
            end
          else
            unquote(repo).insert(changeset)
          end
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
        @spec unquote(:"create_#{resource_name}!")(params :: map(), opts :: Keyword.t()) ::
                unquote(schema).t()
        def unquote(:"create_#{resource_name}!")(params, opts \\ []) do
          has_scope? = Keyword.has_key?(opts, :scope)

          changeset =
            %unquote(schema){}
            |> unquote(schema).changeset(params)

          if has_scope? do
            if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)

            with resource = %unquote(schema){} <- unquote(repo).insert!(changeset) do
              unquote(:"broadcast_#{resource_name}")({:created, resource}, scope: scope)
              resource
            end
          else
            unquote(repo).insert!(changeset)
          end
        end

        defoverridable [
          {unquote(:"create_#{resource_name}"), 1},
          {unquote(:"create_#{resource_name}!"), 1}
        ]
      end

      unless :update in unquote(except) do
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
                params :: map(),
                opts :: Keyword.t()
              ) ::
                {:ok, unquote(schema).t()} | {:error, Ecto.Changeset.t()}
        def unquote(:"update_#{resource_name}")(resource, params, opts \\ []) do
          has_scope? = Keyword.has_key?(opts, :scope)

          changeset =
            resource
            |> unquote(schema).changeset(params)

          if has_scope? do
            if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)
            access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
            key = get_in(scope, access)
            schema_key = Access.key!(unquote(schema_key))

            if get_in(resource, [schema_key]) != key do
              raise "Record not in scope"
            end

            with {:ok, resource = %unquote(schema){}} <-
                   unquote(repo).update(changeset) do
              unquote(:"broadcast_#{resource_name}")({:updated, resource}, scope: scope)
              {:ok, resource}
            end
          else
            unquote(repo).update(changeset)
          end
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
                params :: map(),
                opts :: Keyword.t()
              ) ::
                {:ok, unquote(schema).t()} | Ecto.Changeset.t()
        def unquote(:"update_#{resource_name}!")(resource, params, opts \\ []) do
          has_scope? = Keyword.has_key?(opts, :scope)

          changeset =
            resource
            |> unquote(schema).changeset(params)

          if has_scope? do
            if !unquote(pubsub), do: raise("Missing :pubsub option in `use ContextKit.CRUD`")

            scope = Keyword.get(opts, :scope)
            access = unquote(scope_access_path) |> Enum.map(&Access.key!(&1))
            key = get_in(scope, access)
            schema_key = Access.key!(unquote(schema_key))

            if get_in(resource, [schema_key]) != key do
              raise "Record not in scope"
            end

            with resource = %unquote(schema){} <-
                   unquote(repo).update!(changeset) do
              unquote(:"broadcast_#{resource_name}")({:updated, resource}, scope: scope)
              resource
            end
          else
            unquote(repo).update!(changeset)
          end
        end

        defoverridable [
          {unquote(:"update_#{resource_name}"), 3},
          {unquote(:"update_#{resource_name}!"), 3}
        ]
      end
    end
  end
end
