defmodule ContextKit.Paginator do
  @moduledoc """
  Handles pagination for database queries in ContextKit.

  This module provides pagination functionality with configurable page size,
  automatic limit/offset calculation, and metadata about the paginated results.
  """

  import Ecto.Changeset

  @default_page 1
  @default_per_page 20

  @max_page 100
  @max_per_page 100

  @min_page 1
  @min_per_page 1

  @type t() :: %__MODULE__{}

  defstruct [
    :total_count,
    :total_pages,
    :per_page,
    :current_page,
    :has_next_page?,
    :has_previous_page?,
    :next_page,
    :previous_page,
    :original_paginate_params
  ]

  def new(query, paginate_params, opts \\ []) do
    repo = Keyword.get(opts, :repo)
    params = params(Map.new(paginate_params || %{}))
    total_count = total_count(query, repo)
    total_pages = total_pages(total_count, params.per_page)

    struct!(__MODULE__, %{
      original_paginate_params: paginate_params,
      total_count: total_count,
      total_pages: total_pages,
      per_page: params.per_page,
      current_page: params.page,
      has_next_page?: params.page < total_pages,
      has_previous_page?: params.page > 1,
      next_page: if(params.page < total_pages, do: params.page + 1),
      previous_page: if(params.page > 1, do: params.page - 1)
    })
  end

  def params(raw_params) do
    raw_params = if is_map(raw_params) or Keyword.keyword?(raw_params), do: raw_params, else: []
    data = %{}
    types = %{page: :integer, per_page: :integer}

    changes =
      {data, types}
      |> cast(Map.new(raw_params), Map.keys(types))
      |> apply_changes()

    changes
    |> Enum.into(%{page: @default_page, per_page: @default_per_page})
    |> Map.update!(:page, fn page ->
      cond do
        page > @max_page -> @max_page
        page < @min_page -> @min_page
        :else -> page
      end
    end)
    |> Map.update!(:per_page, fn per_page ->
      cond do
        per_page > @max_per_page -> @max_per_page
        per_page < @min_per_page -> @min_per_page
        :else -> per_page
      end
    end)
  end

  def changed?(paginator, raw_params) do
    params = params(raw_params)

    paginator.current_page != params.page || paginator.per_page != params.per_page
  end

  defp total_pages(total_count, per_page) do
    cond do
      total_count == 0 ->
        0

      rem(total_count, per_page) > 0 ->
        div(total_count, per_page) + 1

      :else ->
        div(total_count, per_page)
    end
  end

  defp total_count(query, repo) do
    query
    |> Ecto.Query.exclude(:limit)
    |> Ecto.Query.exclude(:offset)
    |> repo.aggregate(:count)
  end
end
