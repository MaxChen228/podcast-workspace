import { useMemo, useState } from "react";
import { useLibraryList, useLibraryStore, type LibraryBook } from "../stores/libraryStore";
import { useChaptersQuery } from "../hooks/useChaptersQuery";
import { usePlayer } from "../providers/PlayerProvider";

export function LibraryPage() {
  const books = useLibraryList();
  const [searchTerm, setSearchTerm] = useState("");

  const filteredBooks = useMemo(() => {
    if (!searchTerm.trim()) return books;
    const keyword = searchTerm.trim().toLowerCase();
    return books.filter((book) => book.title.toLowerCase().includes(keyword));
  }, [books, searchTerm]);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>我的書庫</h1>
          <p className="muted">收藏的書籍只儲存在本機裝置，可隨時切換伺服器同步章節資訊。</p>
        </div>
        <div className="search-group">
          <input
            placeholder="搜尋收藏書籍"
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            aria-label="搜尋收藏書籍"
          />
        </div>
      </div>

      {books.length === 0 && <p className="muted">尚未加入任何書籍，請先到「書城」探索。</p>}
      {books.length > 0 && filteredBooks.length === 0 && <p className="muted">找不到符合的書籍</p>}

      <div className="stack">
        {filteredBooks.map((book) => (
          <LibraryCard key={book.id} book={book} />
        ))}
      </div>
    </div>
  );
}

function LibraryCard({ book }: { book: LibraryBook }) {
  const removeBook = useLibraryStore((state) => state.removeBook);
  const { data: chapters, isLoading, isError, refetch } = useChaptersQuery(book.id, true);
  const { play, currentBook, currentChapter, isPlaying, pause, resume } = usePlayer();

  const completedCount =
    chapters?.filter((chapter) => book.completedChapters?.[chapter.id]).length ?? 0;
  const total = chapters?.length ?? 0;

  const handlePlay = () => {
    if (!chapters || chapters.length === 0) return;

    // If already playing this book, toggle
    if (currentBook?.id === book.id) {
      if (isPlaying) pause();
      else resume();
      return;
    }

    // Play first chapter or first uncompleted
    const firstUncompleted = chapters.find(c => !book.completedChapters?.[c.id]);
    play(book, firstUncompleted || chapters[0]);
  };

  const isCurrentBook = currentBook?.id === book.id;

  return (
    <article className="card">
      <header className="card-header">
        <div className="flex gap-4 items-center">
          {book.coverUrl && (
            <img src={book.coverUrl} alt={book.title} className="w-16 h-16 rounded object-cover" />
          )}
          <div>
            <p className="muted">收藏於 {new Date(book.addedAt).toLocaleDateString()}</p>
            <h2>{book.title}</h2>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            className={isCurrentBook && isPlaying ? "secondary" : "primary"}
            onClick={handlePlay}
            disabled={!chapters || chapters.length === 0}
          >
            {isCurrentBook && isPlaying ? "暫停" : "播放"}
          </button>
          <button
            className="ghost danger"
            onClick={(e) => {
              e.stopPropagation(); // Prevent bubbling
              if (confirm(`確定要移除 ${book.title} 嗎？`)) {
                removeBook(book.id);
              }
            }}
          >
            移除
          </button>
        </div>
      </header>
      <p>
        章節完成度：{completedCount}/{total} {total > 0 && `(${Math.round((completedCount / total) * 100)}%)`}
      </p>
      {isLoading && <p className="muted">同步章節中…</p>}
      {isError && (
        <div className="notice error">
          <p>無法取得章節，可能是伺服器 URL 無效。</p>
          <button onClick={() => refetch()}>重試</button>
        </div>
      )}
    </article>
  );
}
