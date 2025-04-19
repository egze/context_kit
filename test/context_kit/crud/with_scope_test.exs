defmodule ContextKit.CRUD.WithScopeTest do
  use ExUnit.Case, async: false

  alias ContextKit.Author
  alias ContextKit.Book
  alias ContextKit.Books
  alias ContextKit.Scope
  alias ContextKit.ScopedBook
  alias ContextKit.ScopedBooks
  alias ContextKit.Test.Repo
  alias ContextKit.User

  setup do
    Repo.delete_all(Book)
    Repo.delete_all(ScopedBook)
    Repo.delete_all(Author)
    Repo.delete_all(User)
    :ok
  end

  describe "subscribe_{:resource}/0-1" do
    test "simple subscribe" do
      assert :ok =
               ScopedBooks.subscribe_scoped_books(
                 scope: %ContextKit.Scope{
                   user: %ContextKit.User{id: 1234, email: "foo@bar.org"}
                 }
               )
    end

    test "requires scope key in opts" do
      assert_raise(KeyError, "key :scope not found in: []", fn ->
        ScopedBooks.subscribe_scoped_books([])
      end)
    end

    test "requires scope value in opts" do
      assert_raise(RuntimeError, "Access.key!/1 expected a map/struct, got: true", fn ->
        ScopedBooks.subscribe_scoped_books(scope: true)
      end)
    end
  end

  describe "broadcast_{:resource}/1-2" do
    test "simple broadcast" do
      :ok =
        ScopedBooks.subscribe_scoped_books(
          scope: %ContextKit.Scope{
            user: %ContextKit.User{id: 1234, email: "foo@bar.org"}
          }
        )

      ScopedBooks.broadcast_scoped_book({:created, 1},
        scope: %ContextKit.Scope{
          user: %ContextKit.User{id: 1234, email: "foo@bar.org"}
        }
      )

      assert_receive {:created, 1}
    end

    test "requires scope key in opts" do
      assert_raise(KeyError, "key :scope not found in: []", fn ->
        ScopedBooks.broadcast_scoped_book({:created, 1}, [])
      end)
    end

    test "requires scope value in opts" do
      assert_raise(RuntimeError, "Access.key!/1 expected a map/struct, got: true", fn ->
        ScopedBooks.broadcast_scoped_book({:created, 1}, scope: true)
      end)
    end
  end

  describe "list_{:resource}/0-1" do
    test "simple list" do
      assert {:ok, scoped_book} = Repo.insert(%ScopedBook{title: "My Book"})

      assert [db_book] = ScopedBooks.list_scoped_books()

      assert scoped_book.id == db_book.id
    end

    test "filters by scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      book_id = book.id

      scope = %Scope{
        user: user
      }

      wrong_scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert [%ScopedBook{id: ^book_id}] = ScopedBooks.list_scoped_books(scope: scope)
      assert [] = ScopedBooks.list_scoped_books(scope: wrong_scope)
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
    test "gets resource by id without scope" do
      assert {:ok, scoped_book} = Repo.insert(%ScopedBook{title: "My Book"})
      scoped_book_id = scoped_book.id

      assert %ScopedBook{id: ^scoped_book_id} = ScopedBooks.get_scoped_book(scoped_book_id)
      refute ScopedBooks.get_scoped_book(scoped_book_id + 1)
    end

    test "filters by scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Author", user_id: user.id})
      scoped_book_id = scoped_book.id

      scope = %Scope{
        user: user
      }

      wrong_scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert %ScopedBook{id: ^scoped_book_id} =
               ScopedBooks.get_scoped_book(scoped_book_id, scope: scope)

      refute ScopedBooks.get_scoped_book(scoped_book_id, scope: wrong_scope)
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
    test "gets resource by id without scope" do
      assert {:ok, book} = Repo.insert(%ScopedBook{title: "My Book"})
      book_id = book.id

      assert %ScopedBook{id: ^book_id} = ScopedBooks.get_scoped_book!(book_id)

      assert_raise Ecto.NoResultsError, fn ->
        ScopedBooks.get_scoped_book!(book_id + 1)
      end
    end

    test "filters by scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Author", user_id: user.id})
      scoped_book_id = scoped_book.id

      scope = %Scope{
        user: user
      }

      wrong_scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert %ScopedBook{id: ^scoped_book_id} =
               ScopedBooks.get_scoped_book!(scoped_book_id, scope: scope)

      assert_raise Ecto.NoResultsError, fn ->
        ScopedBooks.get_scoped_book!(scoped_book_id, scope: wrong_scope)
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
    test "gets single resource by criteria without scope" do
      assert {:ok, book} = Repo.insert(%ScopedBook{title: "My Book"})
      book_id = book.id

      assert %ScopedBook{id: ^book_id} = ScopedBooks.one_scoped_book(title: "My Book")
      refute ScopedBooks.one_scoped_book(title: "Wrong Title")
    end

    test "filters by scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      scoped_book_id = scoped_book.id

      scope = %Scope{
        user: user
      }

      wrong_scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert %ScopedBook{id: ^scoped_book_id} =
               ScopedBooks.one_scoped_book(title: "My Book", scope: scope)

      refute ScopedBooks.one_scoped_book(title: "My Book", scope: wrong_scope)
    end

    test "one! filters by scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      scoped_book_id = scoped_book.id

      scope = %Scope{
        user: user
      }

      wrong_scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert %ScopedBook{id: ^scoped_book_id} =
               ScopedBooks.one_scoped_book!(title: "My Book", scope: scope)

      assert_raise Ecto.NoResultsError, fn ->
        ScopedBooks.one_scoped_book!(title: "My Book", scope: wrong_scope)
      end
    end

    test "gets single resource with complex filters" do
      now = NaiveDateTime.utc_now()
      assert {:ok, book} = Repo.insert(%ScopedBook{title: "My Book"})
      book_id = book.id

      assert %ScopedBook{id: ^book_id} =
               ScopedBooks.one_scoped_book(
                 filters: [
                   %{field: :inserted_at, op: :>, value: NaiveDateTime.shift(now, minute: -1)}
                 ]
               )

      refute ScopedBooks.one_scoped_book(
               filters: [
                 %{field: :inserted_at, op: :<, value: now}
               ]
             )
    end

    test "raises error when multiple results found" do
      assert {:ok, _} = Repo.insert(%ScopedBook{title: "Same Title"})
      assert {:ok, _} = Repo.insert(%ScopedBook{title: "Same Title"})

      assert_raise Ecto.MultipleResultsError, fn ->
        ScopedBooks.one_scoped_book(title: "Same Title")
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
    test "deletes the resource struct without scope" do
      assert {:ok, scoped_book} = Repo.insert(%ScopedBook{title: "My Book"})
      assert {:ok, %ScopedBook{}} = ScopedBooks.delete_scoped_book(scoped_book)
      refute ScopedBooks.get_scoped_book(scoped_book.id)
    end

    test "deletes the resource struct with scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})

      assert {:ok, %ScopedBook{}} =
               ScopedBooks.delete_scoped_book(scoped_book,
                 scope: %Scope{
                   user: user
                 }
               )

      refute ScopedBooks.get_scoped_book(scoped_book.id)
    end

    test "raises error if user not in scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})

      assert_raise RuntimeError, "Record not in scope", fn ->
        ScopedBooks.delete_scoped_book(scoped_book,
          scope: %Scope{
            user: %User{
              id: user.id + 1
            }
          }
        )
      end
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

  describe "change_{:resource}/2" do
    test "returns a changeset for the resource without scope" do
      scoped_book = %ScopedBook{title: "Original Title"}

      changeset = ScopedBooks.change_scoped_book(scoped_book)
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == scoped_book
      assert changeset.valid?
    end

    test "returns a changeset with scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})

      scope = %Scope{
        user: user
      }

      changeset = ScopedBooks.change_scoped_book(scoped_book, %{}, scope: scope)
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == scoped_book
      assert changeset.valid?

      changeset = ScopedBooks.change_scoped_book(scoped_book, scope: scope)
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == scoped_book
      assert changeset.valid?
    end

    test "raises error if not in scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})

      scope = %Scope{
        user: %User{
          id: user.id + 1
        }
      }

      assert_raise RuntimeError, "Record not in scope", fn ->
        ScopedBooks.change_scoped_book(scoped_book, scope: scope)
      end
    end

    test "applies changes when params are provided" do
      book = %Book{title: "Original Title"}
      params = %{title: "New Title"}

      changeset = Books.change_book(book, params)
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes == %{title: "New Title"}
      assert changeset.valid?
    end

    test "validates changes according to schema rules" do
      book = %Book{title: "Original Title"}
      # Assuming title is required
      params = %{title: ""}

      changeset = Books.change_book(book, params)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
      assert changeset.errors[:title]
    end
  end

  describe "create_{:resource}/1" do
    test "creates resource with valid attributes without scope" do
      attrs = %{title: "New Book"}
      assert {:ok, %ScopedBook{} = scoped_book} = ScopedBooks.create_scoped_book(attrs)
      assert scoped_book.title == "New Book"
      assert scoped_book.id
      refute scoped_book.user_id
    end

    test "creates resource with scope and broadcasts message" do
      user = Repo.insert!(%User{email: "user@test.com"})
      attrs = %{title: "My Book"}

      scope = %Scope{
        user: user
      }

      ScopedBooks.subscribe_scoped_books(scope: scope)

      assert {:ok, scoped_book} = ScopedBooks.create_scoped_book(attrs, scope: scope)
      assert scoped_book.user_id == user.id

      assert_received {:created, ^scoped_book}
    end

    test "returns error changeset with invalid attributes" do
      # Assuming title is required
      attrs = %{title: ""}
      assert {:error, %Ecto.Changeset{} = changeset} = Books.create_book(attrs)
      assert changeset.errors[:title]
    end

    test "create! creates resource with valid attributes without scope" do
      attrs = %{title: "New Book"}
      assert %ScopedBook{} = book = ScopedBooks.create_scoped_book!(attrs)
      assert book.title == "New Book"
      assert book.id
    end

    test "create! creates resource with valid attributes with scope" do
      user = Repo.insert!(%User{email: "user@test.com"})

      scope = %Scope{
        user: user
      }

      attrs = %{title: "New Book"}
      assert %ScopedBook{} = book = ScopedBooks.create_scoped_book!(attrs, scope: scope)
      assert book.title == "New Book"
      assert book.id
      assert book.user_id == user.id
    end

    test "create! raises with invalid attributes" do
      attrs = %{title: ""}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Books.create_book!(attrs)
      end
    end
  end

  describe "update_{:resource}/2-3" do
    test "updates resource with valid attributes without scope" do
      scoped_book = Repo.insert!(%ScopedBook{title: "Original Title"})
      attrs = %{title: "Updated Title"}

      assert {:ok, %ScopedBook{} = updated_scoped_book} = ScopedBooks.update_scoped_book(scoped_book, attrs)
      assert updated_scoped_book.title == "Updated Title"
      assert updated_scoped_book.id == scoped_book.id
    end

    test "updates resource with scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      attrs = %{title: "Updated Title"}

      assert {:ok, %ScopedBook{} = updated_scoped_book} =
               ScopedBooks.update_scoped_book(scoped_book, attrs,
                 scope: %Scope{
                   user: user
                 }
               )

      assert updated_scoped_book.title == "Updated Title"
      assert updated_scoped_book.id == scoped_book.id
    end

    test "update broadcasts message" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      attrs = %{title: "Updated Title"}

      scope = %Scope{
        user: user
      }

      ScopedBooks.subscribe_scoped_books(scope: scope)

      assert {:ok, %ScopedBook{} = updated_scoped_book} =
               ScopedBooks.update_scoped_book(scoped_book, attrs, scope: scope)

      assert_received {:updated, ^updated_scoped_book}
    end

    test "update raises error if user not in scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      attrs = %{title: "Updated Title"}

      assert_raise RuntimeError, "Record not in scope", fn ->
        ScopedBooks.update_scoped_book(scoped_book, attrs,
          scope: %Scope{
            user: %User{
              id: user.id + 1
            }
          }
        )
      end
    end

    test "returns error changeset with invalid attributes" do
      book = Repo.insert!(%Book{title: "Original Title"})
      # Assuming title is required
      attrs = %{title: ""}

      assert {:error, %Ecto.Changeset{} = changeset} = Books.update_book(book, attrs)
      assert changeset.errors[:title]
      # Verify the record wasn't updated
      assert Repo.get!(Book, book.id).title == "Original Title"
    end

    test "update! updates resource with valid attributes without scope" do
      scoped_book = Repo.insert!(%ScopedBook{title: "Original Title"})
      attrs = %{title: "Updated Title"}

      assert %ScopedBook{} = updated_scoped_book = ScopedBooks.update_scoped_book!(scoped_book, attrs)
      assert updated_scoped_book.title == "Updated Title"
      assert updated_scoped_book.id == scoped_book.id
    end

    test "update! raises error if user not in scope" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      attrs = %{title: "Updated Title"}

      assert_raise RuntimeError, "Record not in scope", fn ->
        ScopedBooks.update_scoped_book!(scoped_book, attrs,
          scope: %Scope{
            user: %User{
              id: user.id + 1
            }
          }
        )
      end
    end

    test "update! broadcasts message" do
      user = Repo.insert!(%User{email: "user@test.com"})
      scoped_book = Repo.insert!(%ScopedBook{title: "My Book", user_id: user.id})
      attrs = %{title: "Updated Title"}

      scope = %Scope{
        user: user
      }

      ScopedBooks.subscribe_scoped_books(scope: scope)

      assert %ScopedBook{} =
               updated_scoped_book =
               ScopedBooks.update_scoped_book!(scoped_book, attrs, scope: scope)

      assert_received {:updated, ^updated_scoped_book}
    end

    test "update! raises with invalid attributes" do
      book = Repo.insert!(%Book{title: "Original Title"})
      attrs = %{title: ""}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Books.update_book!(book, attrs)
      end

      # Verify the record wasn't updated
      assert Repo.get!(Book, book.id).title == "Original Title"
    end
  end
end
