defmodule ContextKit.CRUDTest do
  use ExUnit.Case, async: false

  alias ContextKit.Book
  alias ContextKit.Books
  alias ContextKit.Author
  alias ContextKit.Test.Repo

  describe "list_{:resource}/0-1" do
    setup do
      Repo.delete_all(Book)
      Repo.delete_all(Author)
      :ok
    end

    test "simple list" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})

      assert [db_book] = Books.list_books()

      assert book.id == db_book.id
    end

    test "filters by fields in keyword list" do
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, book} = Repo.insert(%Book{title: "My Book", author_id: author.id})
      book_id = book.id

      assert [%Book{id: ^book_id}] = Books.list_books(title: "My Book")
      assert [] = Books.list_books(title: "Doesn't Exist")
      assert [%Book{id: ^book_id}] = Books.list_books(author_id: author.id)
      assert [] = Books.list_books(author_id: author.id + 1)
      assert [%Book{id: ^book_id}] = Books.list_books(author: author)
    end

    test "filters by fields in :filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, book_1} = Repo.insert(%Book{title: "Book: Part 1", author_id: author.id})
      assert {:ok, book_2} = Repo.insert(%Book{title: "Book: Part 2", author_id: author.id})
      book_1_id = book_1.id
      book_2_id = book_2.id

      assert [%Book{id: ^book_1_id}] =
               Books.list_books(
                 filters: [
                   %{field: :title, op: :==, value: "Book: Part 1"}
                 ]
               )

      assert [%Book{id: ^book_1_id}, %Book{id: ^book_2_id}] =
               Books.list_books(
                 filters: [
                   %{field: :title, op: :like, value: "Book"}
                 ]
               )

      assert [%Book{id: ^book_1_id}, %Book{id: ^book_2_id}] =
               Books.list_books(
                 filters: [
                   %{field: :inserted_at, op: :>, value: NaiveDateTime.shift(now, minute: -1)}
                 ]
               )

      assert [] =
               Books.list_books(
                 filters: [
                   %{field: :inserted_at, op: :<, value: now}
                 ]
               )
    end

    test "sorts by :order_by" do
      assert {:ok, book_1} = Repo.insert(%Book{title: "Book: Part 1"})
      assert {:ok, book_3} = Repo.insert(%Book{title: "Book: Part 3"})
      assert {:ok, book_2} = Repo.insert(%Book{title: "Book: Part 2"})
      book_1_id = book_1.id
      book_2_id = book_2.id
      book_3_id = book_3.id

      assert [%Book{id: ^book_1_id}, %Book{id: ^book_2_id}, %Book{id: ^book_3_id}] =
               Books.list_books(order_by: [:title])

      assert [%Book{id: ^book_3_id}, %Book{id: ^book_2_id}, %Book{id: ^book_1_id}] =
               Books.list_books(order_by: [desc: :title])
    end

    test "limits by :limit" do
      assert {:ok, book_1} = Repo.insert(%Book{title: "Book: Part 1"})
      assert {:ok, book_2} = Repo.insert(%Book{title: "Book: Part 2"})
      book_1_id = book_1.id
      book_2_id = book_2.id

      assert [%Book{id: ^book_1_id}] = Books.list_books(limit: 1)
      assert [%Book{id: ^book_1_id}, %Book{id: ^book_2_id}] = Books.list_books(limit: 2)
      assert [%Book{id: ^book_2_id}] = Books.list_books(limit: 1, order_by: [desc: :title])
    end

    test "preloads by :preload" do
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, _book} = Repo.insert(%Book{title: "Book: Part 1", author_id: author.id})

      assert [book] = Books.list_books(limit: 1, preload: [:author])
      assert %Author{} = book.author
      assert book.author.id == author.id
    end

    test "paginates by :paginate" do
      assert {:ok, book_1} = Repo.insert(%Book{title: "Book: Part 1"})
      assert {:ok, book_2} = Repo.insert(%Book{title: "Book: Part 2"})
      book_1_id = book_1.id
      book_2_id = book_2.id

      assert {[%Book{id: ^book_1_id}], %ContextKit.Paginator{}} =
               Books.list_books(paginate: [per_page: 1, page: 1])

      assert {[%Book{id: ^book_2_id}], %ContextKit.Paginator{}} =
               Books.list_books(paginate: [per_page: 1, page: 2])

      assert {[], %ContextKit.Paginator{}} = Books.list_books(paginate: [per_page: 1, page: 3])

      assert {[%Book{id: ^book_1_id}, %Book{id: ^book_2_id}], %ContextKit.Paginator{}} =
               Books.list_books(paginate: true)
    end
  end

  describe "get_{:resource}/1-2" do
    setup do
      Repo.delete_all(Book)
      Repo.delete_all(Author)
      :ok
    end

    test "gets resource by id" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.get_book(book_id)
      refute Books.get_book(book_id + 1)
    end

    test "gets resource by id with options" do
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, book} = Repo.insert(%Book{title: "My Book", author_id: author.id})
      book_id = book.id

      assert %Book{id: ^book_id, author: %Author{}} = Books.get_book(book_id, preload: [:author])
      assert %Book{id: ^book_id} = Books.get_book(book_id, title: "My Book")
      refute Books.get_book(book_id, title: "Wrong Title")
    end

    test "gets resource with complex filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} =
               Books.get_book(
                 book_id,
                 filters: [
                   %{field: :inserted_at, op: :>, value: NaiveDateTime.shift(now, minute: -1)}
                 ]
               )

      refute Books.get_book(
               book_id,
               filters: [
                 %{field: :inserted_at, op: :<, value: now}
               ]
             )
    end

    test "gets resource with order_by (should not affect single record)" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.get_book(book_id, order_by: [desc: :title])
    end
  end

  describe "get_{:resource}!/1-2" do
    setup do
      Repo.delete_all(Book)
      Repo.delete_all(Author)
      :ok
    end

    test "gets resource by id" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.get_book!(book_id)

      assert_raise Ecto.NoResultsError, fn ->
        Books.get_book!(book_id + 1)
      end
    end

    test "get! with options raises when resource not found" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.get_book!(book_id, title: "My Book")

      assert_raise Ecto.NoResultsError, fn ->
        Books.get_book!(book_id, title: "Wrong Title")
      end
    end
  end

  describe "one_{:resource}/1" do
    setup do
      Repo.delete_all(Book)
      Repo.delete_all(Author)
      :ok
    end

    test "gets single resource by criteria" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.one_book(title: "My Book")
      refute Books.one_book(title: "Wrong Title")
    end

    test "gets single resource with complex filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} =
               Books.one_book(
                 filters: [
                   %{field: :inserted_at, op: :>, value: NaiveDateTime.shift(now, minute: -1)}
                 ]
               )

      refute Books.one_book(
               filters: [
                 %{field: :inserted_at, op: :<, value: now}
               ]
             )
    end

    test "raises error when multiple results found" do
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})

      assert_raise Ecto.MultipleResultsError, fn ->
        Books.one_book(title: "Same Title")
      end
    end

    test "supports preloading associations" do
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, book} = Repo.insert(%Book{title: "My Book", author_id: author.id})
      book_id = book.id

      assert %Book{id: ^book_id, author: %Author{}} =
               Books.one_book(title: "My Book", preload: [:author])
    end

    test "one! raises when no result found" do
      assert_raise Ecto.NoResultsError, fn ->
        Books.one_book!(title: "Non Existent")
      end
    end

    test "one! returns result when single match found" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      book_id = book.id

      assert %Book{id: ^book_id} = Books.one_book!(title: "My Book")
    end

    test "one! raises when multiple results found" do
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})

      assert_raise Ecto.MultipleResultsError, fn ->
        Books.one_book!(title: "Same Title")
      end
    end
  end

  describe "delete_{:resource}/1" do
    setup do
      Repo.delete_all(Book)
      Repo.delete_all(Author)
      :ok
    end

    test "deletes the resource struct" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      assert {:ok, %Book{}} = Books.delete_book(book)
      refute Books.get_book(book.id)
    end

    test "returns error when trying to delete non-existent resource by query" do
      assert {:error, :not_found} = Books.delete_book(title: "Non Existent")
    end

    test "deletes resource by query criteria" do
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})
      assert {:ok, %Book{}} = Books.delete_book(title: "My Book")
      refute Books.get_book(book.id)
    end

    test "returns error when multiple records match criteria" do
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})
      assert {:ok, _} = Repo.insert(%Book{title: "Same Title"})

      assert {:error, :multiple_entries_found} = Books.delete_book(title: "Same Title")
    end

    test "deletes resource with complex filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, book} = Repo.insert(%Book{title: "My Book"})

      assert {:ok, %Book{}} =
               Books.delete_book(
                 filters: [
                   %{field: :inserted_at, op: :>, value: NaiveDateTime.shift(now, minute: -1)}
                 ]
               )

      refute Books.get_book(book.id)
    end

    test "returns error when no resource matches complex filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, _book} = Repo.insert(%Book{title: "My Book"})

      assert {:error, :not_found} =
               Books.delete_book(
                 filters: [
                   %{field: :inserted_at, op: :<, value: now}
                 ]
               )
    end

    test "deletes resource by associated record" do
      assert {:ok, author} = Repo.insert(%Author{name: "Bob"})
      assert {:ok, book} = Repo.insert(%Book{title: "My Book", author_id: author.id})

      assert {:ok, %Book{}} = Books.delete_book(author: author)
      refute Books.get_book(book.id)
    end
  end
end
