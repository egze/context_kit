defmodule ContextKit.Query do
  @moduledoc """
  Provides dynamic query building functionality with extensive filtering operations for Ecto queries.

  This module is core to ContextKit's filtering capabilities, providing a flexible way to build
  complex database queries from runtime parameters.

  ## Query Building

  The query building process consists of:
  1. Creating a base query with proper binding names
  2. Applying field filters based on schema fields
  3. Applying standard query options (order_by, limit, etc.)
  4. Applying custom query options

  ## Field Filters

  Supports an extensive set of filter operations through a standardized filter syntax:

  ```elixir
  %{field: field_name, op: operator, value: value}
  ```

  ### Available Operators

  Basic Comparison:
  - `:==` - Equality
  - `:!=` - Inequality
  - `:<` - Less than
  - `:<=` - Less than or equal
  - `:>` - Greater than
  - `:>=` - Greater than or equal

  Null Checks:
  - `:empty` - Check if field is NULL
  - `:not_empty` - Check if field is NOT NULL

  List Operations:
  - `:in` - Check if field value is in list
  - `:not_in` - Check if field value is not in list
  - `:contains` - Check if list field contains value
  - `:not_contains` - Check if list field does not contain value

  Pattern Matching:
  - `:like` - Case-sensitive pattern matching
  - `:not_like` - Negative case-sensitive pattern matching
  - `:ilike` - Case-insensitive pattern matching
  - `:not_ilike` - Negative case-insensitive pattern matching
  - `:=~` - Shorthand for `:ilike`

  Multiple Pattern Matching:
  - `:like_and` - All patterns must match (case-sensitive)
  - `:like_or` - Any pattern must match (case-sensitive)
  - `:ilike_and` - All patterns must match (case-insensitive)
  - `:ilike_or` - Any pattern must match (case-insensitive)

  ## Standard Query Options

    The following standard query options are supported:

    - `:order_by` - Specify sort order
    - `:group_by` - Group results
    - `:limit` - Limit number of results
    - `:preload` - Preload associations
    - `:paginate` - Enable pagination with optional configuration
  """

  import Ecto.Query

  alias ContextKit.Paginator

  @base_keys [
    :group_by,
    :limit,
    :limit,
    :order_by,
    :paginate,
    :preload
  ]

  def new(schema) do
    binding_name = binding_name(schema)

    from(_ in schema, as: ^binding_name)
  end

  def build(query, schema, options) do
    base_options = Map.new(options)

    binding_name = binding_name(schema)

    {field_filters, query_options} =
      extract_field_filters(base_options, field_filter_keys(schema))

    field_filters = transform_field_filters(field_filters)

    {query_options, custom_query_options} =
      Enum.reduce(query_options, {[], []}, fn
        {field, _} = query_option, {valid_acc, invalid_acc} ->
          if field in @base_keys,
            do: {[query_option | valid_acc], invalid_acc},
            else: {valid_acc, [query_option | invalid_acc]}

        %{field: field} = query_option, {valid_acc, invalid_acc} ->
          if field in @base_keys,
            do: {[query_option | valid_acc], invalid_acc},
            else: {valid_acc, [query_option | invalid_acc]}

        query_option, {valid_acc, invalid_acc} ->
          {valid_acc, [query_option | invalid_acc]}
      end)

    query =
      query
      |> apply_field_filters(field_filters, binding_name)
      |> apply_query_options(query_options, binding_name)

    {query, custom_query_options}
  end

  defp extract_field_filters(
         base_options,
         schema_fields,
         field_filters_acc \\ [],
         query_options_acc \\ []
       ) do
    Enum.reduce(base_options, {field_filters_acc, query_options_acc}, fn option,
                                                                         {field_filters_acc,
                                                                          query_options_acc} ->
      case option do
        {:filters, filters} ->
          extract_field_filters(filters, schema_fields, field_filters_acc, query_options_acc)

        {field, _} ->
          if field in schema_fields,
            do: {[option | field_filters_acc], query_options_acc},
            else: {field_filters_acc, [option | query_options_acc]}

        %{field: field} ->
          if field in schema_fields,
            do: {[option | field_filters_acc], query_options_acc},
            else: {field_filters_acc, [option | query_options_acc]}

        _ ->
          {field_filters_acc, [option | query_options_acc]}
      end
    end)
  end

  defp transform_field_filters(field_filters) do
    Enum.map(field_filters, fn
      {field, value} when is_binary(field) ->
        %{field: String.to_existing_atom(field), op: :==, value: value}

      {field, value} when is_atom(field) ->
        %{field: field, op: :==, value: value}

      filter ->
        filter
    end)
  end

  defp apply_field_filters(query, field_filters, binding_name) do
    field_filters
    |> Enum.reduce(query, fn field_filter, query_acc ->
      apply_field_filter(field_filter, query_acc, binding_name)
    end)
  end

  defp apply_query_options(query, query_options, binding_name) do
    query_options
    |> Enum.reduce(query, fn query_option, query_acc ->
      apply_query_option(query_option, query_acc, binding_name)
    end)
  end

  def field_filter_keys(schema) do
    schema.__schema__(:fields) ++ [:filters]
  end

  def query_options_keys(_schema) do
    @base_keys
  end

  defp binding_name(schema) do
    schema |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp apply_field_filter(%{field: field, op: :==, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) == ^value)
  end

  defp apply_field_filter(%{field: field, op: :!=, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) != ^value)
  end

  defp apply_field_filter(%{field: field, op: :=~, value: value}, query, binding_name) do
    where(
      query,
      [{^binding_name, record}],
      ilike(field(record, ^field), ^"%#{value}%")
    )
  end

  defp apply_field_filter(%{field: field, op: :empty, value: true}, query, binding_name) do
    where(query, [{^binding_name, record}], is_nil(field(record, ^field)))
  end

  defp apply_field_filter(%{field: field, op: :empty, value: false}, query, binding_name) do
    where(query, [{^binding_name, record}], not is_nil(field(record, ^field)))
  end

  defp apply_field_filter(%{field: field, op: :not_empty, value: true}, query, binding_name) do
    where(query, [{^binding_name, record}], not is_nil(field(record, ^field)))
  end

  defp apply_field_filter(%{field: field, op: :not_empty, value: false}, query, binding_name) do
    where(query, [{^binding_name, record}], is_nil(field(record, ^field)))
  end

  defp apply_field_filter(%{field: field, op: :<=, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) <= ^value)
  end

  defp apply_field_filter(%{field: field, op: :<, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) < ^value)
  end

  defp apply_field_filter(%{field: field, op: :>=, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) >= ^value)
  end

  defp apply_field_filter(%{field: field, op: :>, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], field(record, ^field) > ^value)
  end

  defp apply_field_filter(%{field: field, op: :in, value: value}, query, binding_name)
       when is_list(value) do
    where(query, [{^binding_name, record}], field(record, ^field) in ^value)
  end

  defp apply_field_filter(%{field: field, op: :not_in, value: value}, query, binding_name)
       when is_list(value) do
    where(query, [{^binding_name, record}], field(record, ^field) not in ^value)
  end

  defp apply_field_filter(%{field: field, op: :contains, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], ^value in field(record, ^field))
  end

  defp apply_field_filter(%{field: field, op: :not_contains, value: value}, query, binding_name) do
    where(query, [{^binding_name, record}], ^value not in field(record, ^field))
  end

  defp apply_field_filter(%{field: field, op: :like, value: value}, query, binding_name) do
    where(
      query,
      [{^binding_name, record}],
      like(field(record, ^field), ^"%#{value}%")
    )
  end

  defp apply_field_filter(%{field: field, op: :not_like, value: value}, query, binding_name) do
    where(
      query,
      [{^binding_name, record}],
      not like(field(record, ^field), ^"%#{value}%")
    )
  end

  defp apply_field_filter(%{field: field, op: :like_and, value: value}, query, binding_name) do
    values = if is_binary(value), do: String.split(value), else: value

    Enum.reduce(values, query, fn v, acc ->
      where(acc, [{^binding_name, record}], like(field(record, ^field), ^"%#{v}%"))
    end)
  end

  defp apply_field_filter(%{field: field, op: :like_or, value: value}, query, binding_name) do
    values = if is_binary(value), do: String.split(value), else: value

    where(
      query,
      [{^binding_name, record}],
      fragment("? LIKE ANY(?)", field(record, ^field), ^Enum.map(values, &"%#{&1}%"))
    )
  end

  defp apply_field_filter(%{field: field, op: :ilike, value: value}, query, binding_name) do
    where(
      query,
      [{^binding_name, record}],
      ilike(field(record, ^field), ^"%#{value}%")
    )
  end

  defp apply_field_filter(%{field: field, op: :not_ilike, value: value}, query, binding_name) do
    where(
      query,
      [{^binding_name, record}],
      not ilike(field(record, ^field), ^"%#{value}%")
    )
  end

  defp apply_field_filter(%{field: field, op: :ilike_and, value: value}, query, binding_name) do
    values = if is_binary(value), do: String.split(value), else: value

    Enum.reduce(values, query, fn v, acc ->
      where(acc, [{^binding_name, record}], ilike(field(record, ^field), ^"%#{v}%"))
    end)
  end

  defp apply_field_filter(%{field: field, op: :ilike_or, value: value}, query, binding_name) do
    values = if is_binary(value), do: String.split(value), else: value

    where(
      query,
      [{^binding_name, record}],
      fragment("? ILIKE ANY(?)", field(record, ^field), ^Enum.map(values, &"%#{&1}%"))
    )
  end

  defp apply_query_option({:order_by, order_by}, query, _binding_name) do
    order_by(query, ^order_by)
  end

  defp apply_query_option({:group_by, group_by}, query, _binding_name) do
    group_by(query, ^group_by)
  end

  defp apply_query_option({:limit, limit}, query, _binding_name) do
    limit(query, ^limit)
  end

  defp apply_query_option({:preload, preload}, query, _binding_name) do
    preload(query, ^preload)
  end

  defp apply_query_option({:paginate, paginate_opts}, query, _binding_name) do
    params = Paginator.params(paginate_opts)
    offset = (params.page - 1) * params.per_page

    query
    |> limit(^params.per_page)
    |> offset(^offset)
  end
end
