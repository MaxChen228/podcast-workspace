import { useMemo, useState } from "react";
import { useBooksQuery } from "../hooks/useBooksQuery";
import { useChaptersQuery } from "../hooks/useChaptersQuery";
import type { BookItem } from "../types/api";
import { BookDetailDrawer } from "../components/BookDetailDrawer";
import { useLibraryStore } from "../stores/libraryStore";

export function StorePage() {
  const { data: books, isLoading, isError, refetch } = useBooksQuery();
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedBook, setSelectedBook] = useState<BookItem | null>(null);
  const addBook = useLibraryStore((state) => state.addBook);
  const toggleChapterCompletion = useLibraryStore((state) => state.toggleChapterCompletion);
  const libraryBooks = useLibraryStore((state) => state.books);

  const { data: chapters, isLoading: isLoadingChapters } = useChaptersQuery(
    selectedBook?.id,
    Boolean(selectedBook)
  );

  const filteredBooks = useMemo(() => {
    if (!books) return [];
    if (!searchTerm.trim()) return books;
    const keyword = searchTerm.trim().toLowerCase();
    return books.filter((book) => book.title.toLowerCase().includes(keyword));
  }, [books, searchTerm]);

  const handleSelect = (book: BookItem) => {
    setSelectedBook(book);
  };

  const handleAddBook = (book: BookItem) => {
    addBook({ id: book.id, title: book.title, coverUrl: book.cover_url });
  };

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>書城</h1>
          <p className="muted">瀏覽 FastAPI 後端目前提供的所有書籍</p>
        </div>
        <div className="search-group">
          <input
            placeholder="搜尋書名"
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            aria-label="搜尋書名"
          />
          <button className="ghost" onClick={() => refetch()} disabled={isLoading}>
            重新整理
          </button>
        </div>
      </div>

      {isError && (
        <div className="notice error">
          <p>無法連線到後端 API，請檢查 Server Settings。</p>
          <button onClick={() => refetch()}>重試</button>
        </div>
      )}

      {isLoading && <p>載入書籍中…</p>}

      {!isLoading && filteredBooks.length === 0 && <p className="muted">找不到符合的書籍</p>}

      <div className="grid">
        {filteredBooks.map((book) => (
          <article key={book.id} className="card">
            <div>
              <p className="muted">書籍</p>
              <h2>{book.title}</h2>
            </div>
            <div className="card-actions">
              <button className="ghost" onClick={() => handleSelect(book)}>
                查看章節
              </button>
              <button
                className="primary"
                onClick={() => handleAddBook(book)}
                disabled={Boolean(libraryBooks[book.id])}
              >
                {libraryBooks[book.id] ? "已加入" : "加入書庫"}
              </button>
            </div>
          </article>
        ))}
      </div>

      {selectedBook && (
        <BookDetailDrawer
          book={selectedBook}
          chapters={chapters}
          isLoading={isLoadingChapters}
          onClose={() => setSelectedBook(null)}
          onAddToLibrary={() => handleAddBook(selectedBook)}
          isInLibrary={Boolean(libraryBooks[selectedBook.id])}
          onToggleChapter={(chapterId) => toggleChapterCompletion(selectedBook.id, chapterId)}
          completedChapters={libraryBooks[selectedBook.id]?.completedChapters ?? {}}
        />
      )}
    </div>
  );
}
