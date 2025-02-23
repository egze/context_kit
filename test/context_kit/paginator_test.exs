defmodule ContextKit.PaginatorTest do
  use ExUnit.Case, async: false

  alias ContextKit.Paginator

  describe "params/1" do
    test "returns default values when no params provided" do
      assert %{page: 1, per_page: 20} = Paginator.params(%{})
    end

    test "accepts valid page and per_page values" do
      params = %{page: 2, per_page: 10}
      assert %{page: 2, per_page: 10} = Paginator.params(params)
    end

    test "clamps page to valid range" do
      assert %{page: 1} = Paginator.params(%{page: 0})
      assert %{page: 100} = Paginator.params(%{page: 101})
      assert %{page: 50} = Paginator.params(%{page: 50})
    end

    test "clamps per_page to valid range" do
      assert %{per_page: 1} = Paginator.params(%{per_page: 0})
      assert %{per_page: 100} = Paginator.params(%{per_page: 101})
      assert %{per_page: 50} = Paginator.params(%{per_page: 50})
    end

    test "handles keyword list input" do
      params = [page: 2, per_page: 10]
      assert %{page: 2, per_page: 10} = Paginator.params(params)
    end

    test "ignores non-pagination parameters" do
      params = %{page: 2, per_page: 10, other: "value"}
      assert %{page: 2, per_page: 10} = Paginator.params(params)
    end
  end

  describe "changed?/2" do
    test "returns true when page changes" do
      paginator = %Paginator{current_page: 1, per_page: 20}
      assert Paginator.changed?(paginator, %{page: 2, per_page: 20})
    end

    test "returns true when per_page changes" do
      paginator = %Paginator{current_page: 1, per_page: 20}
      assert Paginator.changed?(paginator, %{page: 1, per_page: 10})
    end

    test "returns false when params are the same" do
      paginator = %Paginator{current_page: 1, per_page: 20}
      refute Paginator.changed?(paginator, %{page: 1, per_page: 20})
    end
  end

  describe "new/3" do
    defmodule MockRepo do
      def aggregate(_, :count), do: 100
    end

    test "creates new paginator with correct calculations" do
      query = %Ecto.Query{}
      params = %{page: 2, per_page: 10}

      paginator = Paginator.new(query, params, repo: MockRepo)

      assert paginator.total_count == 100
      assert paginator.total_pages == 10
      assert paginator.current_page == 2
      assert paginator.per_page == 10
      assert paginator.has_next_page? == true
      assert paginator.has_previous_page? == true
      assert paginator.next_page == 3
      assert paginator.previous_page == 1
      assert paginator.original_paginate_params == params
    end

    test "handles first page correctly" do
      query = %Ecto.Query{}
      params = %{page: 1, per_page: 10}

      paginator = Paginator.new(query, params, repo: MockRepo)

      assert paginator.has_previous_page? == false
      assert paginator.previous_page == nil
      assert paginator.has_next_page? == true
      assert paginator.next_page == 2
    end

    test "handles last page correctly" do
      query = %Ecto.Query{}
      params = %{page: 10, per_page: 10}

      paginator = Paginator.new(query, params, repo: MockRepo)

      assert paginator.has_next_page? == false
      assert paginator.next_page == nil
      assert paginator.has_previous_page? == true
      assert paginator.previous_page == 9
    end

    test "handles empty result set" do
      defmodule EmptyRepo do
        def aggregate(_, :count), do: 0
      end

      query = %Ecto.Query{}
      params = %{page: 1, per_page: 10}

      paginator = Paginator.new(query, params, repo: EmptyRepo)

      assert paginator.total_count == 0
      assert paginator.total_pages == 0
      assert paginator.has_next_page? == false
      assert paginator.has_previous_page? == false
      assert paginator.next_page == nil
      assert paginator.previous_page == nil
    end

    test "handles uneven division of total_count by per_page" do
      defmodule UnevenRepo do
        def aggregate(_, :count), do: 95
      end

      query = %Ecto.Query{}
      params = %{page: 1, per_page: 10}

      paginator = Paginator.new(query, params, repo: UnevenRepo)

      assert paginator.total_count == 95
      # 9 full pages + 1 partial page
      assert paginator.total_pages == 10
    end
  end
end
