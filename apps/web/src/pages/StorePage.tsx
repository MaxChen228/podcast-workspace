import { useMemo, useState } from "react";
import { useBooksQuery } from "../hooks/useBooksQuery";
import { useChaptersQuery } from "../hooks/useChaptersQuery";
import type { BookItem } from "../types/api";
import { BookDetailDrawer } from "../components/BookDetailDrawer";
import { useLibraryStore } from "../stores/libraryStore";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { Badge } from "../components/ui/Badge";
import { Search, RefreshCw, BookOpen, Plus } from "lucide-react";
import { motion } from "framer-motion";

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

  const handleAddBook = (e: React.MouseEvent, book: BookItem) => {
    e.stopPropagation();
    addBook({ id: book.id, title: book.title, coverUrl: book.cover_url });
  };

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-white">書城</h1>
          <p className="text-muted-foreground">瀏覽 FastAPI 後端目前提供的所有書籍</p>
        </div>

        <div className="flex items-center gap-2">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <input
              className="h-10 w-full rounded-lg border border-white/10 bg-surface/50 pl-9 pr-4 text-sm text-white placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary sm:w-64"
              placeholder="搜尋書名..."
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
            />
          </div>
          <Button variant="ghost" size="icon" onClick={() => refetch()} disabled={isLoading}>
            <RefreshCw className={`h-4 w-4 ${isLoading ? "animate-spin" : ""}`} />
          </Button>
        </div>
      </div>

      {isError && (
        <div className="rounded-lg border border-red-500/20 bg-red-500/10 p-4 text-red-400">
          <p>無法連線到後端 API，請檢查 Server Settings。</p>
          <Button variant="danger" size="sm" onClick={() => refetch()} className="mt-2">
            重試
          </Button>
        </div>
      )}

      {isLoading && (
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-64 animate-pulse rounded-xl bg-surface/50" />
          ))}
        </div>
      )}

      {!isLoading && filteredBooks.length === 0 && (
        <div className="flex h-64 flex-col items-center justify-center rounded-xl border border-dashed border-white/10 bg-surface/20 text-muted-foreground">
          <BookOpen className="mb-2 h-8 w-8 opacity-50" />
          <p>找不到符合的書籍</p>
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {filteredBooks.map((book) => {
          const isAdded = Boolean(libraryBooks[book.id]);
          return (
            <motion.div
              key={book.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <Card
                className="group relative cursor-pointer overflow-hidden border-white/5 bg-surface/40 hover:border-primary/50 hover:bg-surface/60"
                onClick={() => handleSelect(book)}
              >
                <div className="aspect-[2/3] w-full overflow-hidden rounded-lg bg-surface-active/50">
                  {book.cover_url ? (
                    <img
                      src={book.cover_url}
                      alt={book.title}
                      className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                      <BookOpen className="h-12 w-12 opacity-20" />
                    </div>
                  )}

                  {/* Overlay Actions */}
                  <div className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                    <Button variant="secondary" className="translate-y-4 transition-transform duration-300 group-hover:translate-y-0">
                      查看詳情
                    </Button>
                  </div>
                </div>

                <div className="mt-4 space-y-2">
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="line-clamp-1 font-semibold text-white group-hover:text-primary">
                      {book.title}
                    </h3>
                    {isAdded && <Badge variant="secondary">已加入</Badge>}
                  </div>

                  <Button
                    variant={isAdded ? "ghost" : "primary"}
                    size="sm"
                    className="w-full"
                    onClick={(e) => handleAddBook(e, book)}
                    disabled={isAdded}
                  >
                    {isAdded ? "已在書庫" : (
                      <>
                        <Plus className="mr-2 h-4 w-4" />
                        加入書庫
                      </>
                    )}
                  </Button>
                </div>
              </Card>
            </motion.div>
          );
        })}
      </div>

      {selectedBook && (
        <BookDetailDrawer
          book={selectedBook}
          chapters={chapters}
          isLoading={isLoadingChapters}
          onClose={() => setSelectedBook(null)}
          onAddToLibrary={() => handleAddBook({ stopPropagation: () => { } } as any, selectedBook)}
          isInLibrary={Boolean(libraryBooks[selectedBook.id])}
          onToggleChapter={(chapterId) => toggleChapterCompletion(selectedBook.id, chapterId)}
          completedChapters={libraryBooks[selectedBook.id]?.completedChapters ?? {}}
        />
      )}
    </div>
  );
}
