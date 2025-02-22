defmodule ContextKit.Queries do
  @moduledoc """
  Provides a set of macros and functions for building and applying dynamic queries.

  This module is designed to be used with Ecto schemas and allows for flexible
  query construction based on various filter criteria. It supports a wide range
  of filter operations including equality, inequality, pattern matching, numeric
  comparisons, and list operations.

  ## Usage

  To use this module, include it in your query module like this:

      defmodule MyApp.Queries.UserQuery do
        use ContextKit.Queries, schema: MyApp.Schemas.User

        # ... rest of your module code ...
      end

  ## Available Filter Operations

  - `:==` - Equality
  - `:!=` - Inequality
  - `:=~` - Case-insensitive pattern matching
  - `:empty` - Check if a field is null
  - `:not_empty` - Check if a field is not null
  - `:<=`, `:<`, `:>=`, `:>` - Numeric comparisons
  - `:in`, `:not_in` - List inclusion/exclusion
  - `:contains`, `:not_contains` - Array operations
  - `:like`, `:not_like` - Case-sensitive pattern matching
  - `:like_and`, `:like_or` - Multiple case-sensitive pattern matching
  - `:ilike`, `:not_ilike` - Case-insensitive pattern matching
  - `:ilike_and`, `:ilike_or` - Multiple case-insensitive pattern matching

  ## Example

      query = MyApp.Queries.UserQuery.build(News.Queries.SourceQuery.new(), %{
        filters: [
          %{field: :email, op: :ilike, value: "john@"}
        ]
      })

  This will create a query that finds records where the email contains "john@"
  (case-insensitive).

  For more details on filter operations and their usage, refer to the individual
  `apply_field_filter/2` function clauses in this module.
  """

  alias ContextKit.Paginator

  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    {_, _, modules} = schema
    binding_name = "#{List.last(modules)}" |> Macro.underscore() |> String.to_atom()

    quote do
      import Ecto.Query

      alias unquote(schema)

      def new do
        from(_ in unquote(schema), as: unquote(binding_name))
      end

      def build(query \\ new(), criteria) do
        {filters, criteria} = extract_field_filters(criteria)

        query
        |> apply_field_filters(filters)
        |> apply_criteria(criteria)
      end

      defp extract_field_filters(criteria) do
        fields = unquote(schema).__schema__(:fields)

        Enum.reduce(criteria, {[], []}, fn filter, {filters_acc, criteria_acc} ->
          case filter do
            {:filters, filters} ->
              {List.wrap(filters) ++ filters_acc, criteria_acc}

            {field, _} ->
              if field in fields,
                do: {[filter | filters_acc], criteria_acc},
                else: {filters_acc, [filter | criteria_acc]}

            %{field: field} ->
              if field in fields,
                do: {[filter | filters_acc], criteria_acc},
                else: {filters_acc, [filter | criteria_acc]}

            _ ->
              {filters_acc, [filter | criteria_acc]}
          end
        end)
      end

      defp transform_filters(filters) do
        Enum.map(filters, fn
          {field, value} when is_binary(field) ->
            %{field: String.to_existing_atom(field), op: :==, value: value}

          {field, value} when is_atom(field) ->
            %{field: field, op: :==, value: value}

          filter ->
            filter
        end)
      end

      defp apply_field_filters(query, filters) do
        filters
        |> transform_filters()
        |> Enum.reduce(query, &apply_field_filter/2)
      end

      defp apply_criteria(query, criteria) do
        Enum.reduce(criteria, query, &apply_criterion/2)
      end

      defp apply_field_filter(%{field: field, op: :==, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) == ^value)
      end

      defp apply_field_filter(%{field: field, op: :!=, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) != ^value)
      end

      defp apply_field_filter(%{field: field, op: :=~, value: value}, query) do
        where(
          query,
          [{^unquote(binding_name), record}],
          ilike(field(record, ^field), ^"%#{value}%")
        )
      end

      defp apply_field_filter(%{field: field, op: :empty, value: true}, query) do
        where(query, [{^unquote(binding_name), record}], is_nil(field(record, ^field)))
      end

      defp apply_field_filter(%{field: field, op: :empty, value: false}, query) do
        where(query, [{^unquote(binding_name), record}], not is_nil(field(record, ^field)))
      end

      defp apply_field_filter(%{field: field, op: :not_empty, value: true}, query) do
        where(query, [{^unquote(binding_name), record}], not is_nil(field(record, ^field)))
      end

      defp apply_field_filter(%{field: field, op: :not_empty, value: false}, query) do
        where(query, [{^unquote(binding_name), record}], is_nil(field(record, ^field)))
      end

      defp apply_field_filter(%{field: field, op: :<=, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) <= ^value)
      end

      defp apply_field_filter(%{field: field, op: :<, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) < ^value)
      end

      defp apply_field_filter(%{field: field, op: :>=, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) >= ^value)
      end

      defp apply_field_filter(%{field: field, op: :>, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) > ^value)
      end

      defp apply_field_filter(%{field: field, op: :in, value: value}, query)
           when is_list(value) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) in ^value)
      end

      defp apply_field_filter(%{field: field, op: :not_in, value: value}, query)
           when is_list(value) do
        where(query, [{^unquote(binding_name), record}], field(record, ^field) not in ^value)
      end

      defp apply_field_filter(%{field: field, op: :contains, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], ^value in field(record, ^field))
      end

      defp apply_field_filter(%{field: field, op: :not_contains, value: value}, query) do
        where(query, [{^unquote(binding_name), record}], ^value not in field(record, ^field))
      end

      defp apply_field_filter(%{field: field, op: :like, value: value}, query) do
        where(
          query,
          [{^unquote(binding_name), record}],
          like(field(record, ^field), ^"%#{value}%")
        )
      end

      defp apply_field_filter(%{field: field, op: :not_like, value: value}, query) do
        where(
          query,
          [{^unquote(binding_name), record}],
          not like(field(record, ^field), ^"%#{value}%")
        )
      end

      defp apply_field_filter(%{field: field, op: :like_and, value: value}, query) do
        values = if is_binary(value), do: String.split(value), else: value

        Enum.reduce(values, query, fn v, acc ->
          where(acc, [{^unquote(binding_name), record}], like(field(record, ^field), ^"%#{v}%"))
        end)
      end

      defp apply_field_filter(%{field: field, op: :like_or, value: value}, query) do
        values = if is_binary(value), do: String.split(value), else: value

        where(
          query,
          [{^unquote(binding_name), record}],
          fragment("? LIKE ANY(?)", field(record, ^field), ^Enum.map(values, &"%#{&1}%"))
        )
      end

      defp apply_field_filter(%{field: field, op: :ilike, value: value}, query) do
        where(
          query,
          [{^unquote(binding_name), record}],
          ilike(field(record, ^field), ^"%#{value}%")
        )
      end

      defp apply_field_filter(%{field: field, op: :not_ilike, value: value}, query) do
        where(
          query,
          [{^unquote(binding_name), record}],
          not ilike(field(record, ^field), ^"%#{value}%")
        )
      end

      defp apply_field_filter(%{field: field, op: :ilike_and, value: value}, query) do
        values = if is_binary(value), do: String.split(value), else: value

        Enum.reduce(values, query, fn v, acc ->
          where(acc, [{^unquote(binding_name), record}], ilike(field(record, ^field), ^"%#{v}%"))
        end)
      end

      defp apply_field_filter(%{field: field, op: :ilike_or, value: value}, query) do
        values = if is_binary(value), do: String.split(value), else: value

        where(
          query,
          [{^unquote(binding_name), record}],
          fragment("? ILIKE ANY(?)", field(record, ^field), ^Enum.map(values, &"%#{&1}%"))
        )
      end

      defp apply_criterion({:order_by, order_by}, query) do
        order_by(query, ^order_by)
      end

      defp apply_criterion({:group_by, group_by}, query) do
        group_by(query, ^group_by)
      end

      defp apply_criterion({:limit, limit}, query) do
        limit(query, ^limit)
      end

      defp apply_criterion({:preload, preload}, query) do
        preload(query, ^preload)
      end

      defp apply_criterion({:paginate, paginate_opts}, query) do
        params = Paginator.params(paginate_opts)
        offset = (params.page - 1) * params.per_page

        query
        |> limit(^params.per_page)
        |> offset(^offset)
      end
    end
  end
end
