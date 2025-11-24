import { useMemo, useState } from "react";
import { useLibraryList, useLibraryStore } from "../stores/libraryStore";
import { LibraryCard } from "../components/LibraryCard";
import { BookDetailDrawer } from "../components/BookDetailDrawer";
import { Search, Library } from "lucide-react";
import { motion } from "framer-motion";
import type { BookItem } from "../types/api";
import { useChaptersQuery } from "../hooks/useChaptersQuery";

export function LibraryPage() {
  const books = useLibraryList();
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedBook, setSelectedBook] = useState<BookItem | null>(null);
  const toggleChapterCompletion = useLibraryStore((state) => state.toggleChapterCompletion);
  const libraryBooks = useLibraryStore((state) => state.books);

  const { data: chapters, isLoading: isLoadingChapters } = useChaptersQuery(
    selectedBook?.id,
    Boolean(selectedBook)
  );

  const filteredBooks = useMemo(() => {
    if (!searchTerm.trim()) return books;
    const keyword = searchTerm.trim().toLowerCase();
    return books.filter((book) => book.title.toLowerCase().includes(keyword));
  }, [books, searchTerm]);

  // Convert LibraryBook to BookItem for the drawer
  const handleSelectBook = (libBook: any) => {
    setSelectedBook({
      id: libBook.id,
      title: libBook.title,
      cover_url: libBook.coverUrl, // Map back to API format if needed
    });
  };

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-white">我的書庫</h1>
          <p className="text-muted-foreground">已收藏的書籍與學習進度</p>
        </div>

        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            className="h-10 w-full rounded-lg border border-white/10 bg-surface/50 pl-9 pr-4 text-sm text-white placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary sm:w-64"
            placeholder="搜尋已收藏書籍..."
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
          />
        </div>
      </div>

      {filteredBooks.length === 0 ? (
        <div className="flex h-64 flex-col items-center justify-center rounded-xl border border-dashed border-white/10 bg-surface/20 text-muted-foreground">
          <Library className="mb-2 h-8 w-8 opacity-50" />
          <p>{searchTerm ? "找不到符合的書籍" : "書庫目前是空的，快去書城加入一些書吧！"}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredBooks.map((book, index) => (
            <motion.div
              key={book.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: index * 0.05 }}
            >
              <LibraryCard book={book} onClick={() => handleSelectBook(book)} />
            </motion.div>
          ))}
        </div>
      )}

      {selectedBook && (
        <BookDetailDrawer
          book={selectedBook}
          chapters={chapters}
          isLoading={isLoadingChapters}
          onClose={() => setSelectedBook(null)}
          onAddToLibrary={() => { }} // Already in library
          isInLibrary={true}
          onToggleChapter={(chapterId) => toggleChapterCompletion(selectedBook.id, chapterId)}
          completedChapters={libraryBooks[selectedBook.id]?.completedChapters ?? {}}
        />
      )}
    </div>
  );
}
