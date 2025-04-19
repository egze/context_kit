defmodule ContextKit.QueryTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias ContextKit.Book
  alias ContextKit.Query

  describe "new/1" do
    test "builds new query" do
      query = Query.new(Book)
      expected_query = from _ in Book, as: :book

      assert inspect(query) == inspect(expected_query)
    end
  end

  describe "build/3" do
    test "builds query" do
      query = Query.new(Book)
      {query, _} = Query.build(query, Book, title: "Test")
      expected_query = from b in Book, as: :book, where: b.title == ^"Test"

      assert inspect(query) == inspect(expected_query)
    end

    test "returns custom query options" do
      query = Query.new(Book)
      {_query, custom_query_options} = Query.build(query, Book, title: "Test", foo: "bar")

      assert custom_query_options == [foo: "bar"]
    end
  end
end
