import { useLibraryList, useLibraryStore, type LibraryBook } from "../stores/libraryStore";
import { useChaptersQuery } from "../hooks/useChaptersQuery";

export function LibraryPage() {
  const books = useLibraryList();

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>我的書庫</h1>
          <p className="muted">收藏的書籍只儲存在本機裝置，可隨時切換伺服器同步章節資訊。</p>
        </div>
      </div>

      {books.length === 0 && <p className="muted">尚未加入任何書籍，請先到「書城」探索。</p>}

      <div className="stack">
        {books.map((book) => (
          <LibraryCard key={book.id} book={book} />
        ))}
      </div>
    </div>
  );
}

function LibraryCard({ book }: { book: LibraryBook }) {
  const removeBook = useLibraryStore((state) => state.removeBook);
  const { data: chapters, isLoading, isError, refetch } = useChaptersQuery(book.id, true);

  const completedCount = chapters?.filter((chapter) => book.completedChapters[chapter.id]).length ?? 0;
  const total = chapters?.length ?? 0;

  return (
    <article className="card">
      <header className="card-header">
        <div>
          <p className="muted">收藏於 {new Date(book.addedAt).toLocaleDateString()}</p>
          <h2>{book.title}</h2>
        </div>
        <button className="ghost danger" onClick={() => removeBook(book.id)}>
          移除
        </button>
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
