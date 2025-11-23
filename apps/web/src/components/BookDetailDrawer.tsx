import { useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Play, CheckCircle, Circle, Pause, BookOpen } from "lucide-react";
import type { BookItem, ChapterItem } from "../types/api";
import { usePlayer } from "../providers/PlayerContext";
import { Button } from "./ui/Button";
import { Badge } from "./ui/Badge";

interface BookDetailDrawerProps {
  book: BookItem;
  chapters?: ChapterItem[];
  isLoading: boolean;
  onClose: () => void;
  onAddToLibrary: () => void;
  isInLibrary: boolean;
  onToggleChapter: (chapterId: string) => void;
  completedChapters: Record<string, boolean>;
}

export function BookDetailDrawer({
  book,
  chapters,
  isLoading,
  onClose,
  onAddToLibrary,
  isInLibrary,
  onToggleChapter,
  completedChapters,
}: BookDetailDrawerProps) {
  const { play, currentChapter, isPlaying, pause, resume } = usePlayer();

  // Close on Escape key
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleEsc);
    return () => window.removeEventListener("keydown", handleEsc);
  }, [onClose]);

  const handlePlay = (chapter: ChapterItem) => {
    if (currentChapter?.id === chapter.id) {
      isPlaying ? pause() : resume();
    } else {
      if (chapters) {
        play(book, chapter, chapters);
      }
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      {/* Backdrop */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={onClose}
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
      />

      {/* Drawer */}
      <motion.div
        initial={{ x: "100%" }}
        animate={{ x: 0 }}
        exit={{ x: "100%" }}
        transition={{ type: "spring", damping: 25, stiffness: 200 }}
        className="relative h-full w-full max-w-md border-l border-white/10 bg-surface shadow-2xl"
      >
        <div className="flex h-full flex-col">
          {/* Header */}
          <div className="flex items-start justify-between p-6 pb-4">
            <div className="flex gap-4">
              <div className="h-24 w-16 flex-shrink-0 overflow-hidden rounded-lg bg-surface-active shadow-lg">
                {book.cover_url ? (
                  <img src={book.cover_url} alt={book.title} className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                    <BookOpen className="h-6 w-6 opacity-20" />
                  </div>
                )}
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">{book.title}</h2>
                <p className="text-sm text-muted-foreground">共 {chapters?.length || 0} 章</p>
                <div className="mt-3">
                  <Button
                    size="sm"
                    variant={isInLibrary ? "secondary" : "primary"}
                    onClick={onAddToLibrary}
                    disabled={isInLibrary}
                  >
                    {isInLibrary ? "已在書庫" : "加入書庫"}
                  </Button>
                </div>
              </div>
            </div>
            <Button variant="ghost" size="icon" onClick={onClose}>
              <X className="h-5 w-5" />
            </Button>
          </div>

          <div className="h-px w-full bg-white/5" />

          {/* Body */}
          <div className="flex-1 overflow-y-auto p-6 pt-4">
            <h3 className="mb-4 text-xs font-bold uppercase tracking-wider text-muted-foreground">
              章節列表
            </h3>

            {isLoading ? (
              <div className="space-y-3">
                {[...Array(5)].map((_, i) => (
                  <div key={i} className="h-16 animate-pulse rounded-xl bg-surface-active/50" />
                ))}
              </div>
            ) : (
              <div className="space-y-2">
                {chapters?.map((chapter, index) => {
                  const isCurrent = currentChapter?.id === chapter.id;
                  const isCompleted = completedChapters[chapter.id];

                  return (
                    <motion.div
                      key={chapter.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.03 }}
                      className={`group relative flex items-center gap-3 rounded-xl border p-3 transition-all ${isCurrent
                        ? "border-primary/50 bg-primary/10"
                        : "border-transparent bg-surface-hover/50 hover:bg-surface-hover"
                        }`}
                    >
                      <button
                        onClick={() => handlePlay(chapter)}
                        className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full transition-all ${isCurrent
                          ? "bg-primary text-white shadow-lg shadow-primary/25"
                          : "bg-surface text-muted-foreground group-hover:bg-primary group-hover:text-white"
                          }`}
                      >
                        {isCurrent && isPlaying ? (
                          <Pause className="h-4 w-4 fill-current" />
                        ) : (
                          <Play className="h-4 w-4 fill-current ml-0.5" />
                        )}
                      </button>

                      <div className="min-w-0 flex-1">
                        <h4 className={`truncate text-sm font-medium ${isCurrent ? "text-primary" : "text-white"}`}>
                          {chapter.title}
                        </h4>
                        <p className="text-xs text-muted-foreground">
                          {/* Duration placeholder if available */}
                          12:34
                        </p>
                      </div>

                      {isInLibrary && (
                        <button
                          onClick={() => onToggleChapter(chapter.id)}
                          className={`flex h-8 w-8 items-center justify-center rounded-full transition-colors ${isCompleted ? "text-green-400 hover:text-green-300" : "text-muted-foreground/30 hover:text-muted-foreground"
                            }`}
                          title={isCompleted ? "標記為未讀" : "標記為已讀"}
                        >
                          {isCompleted ? <CheckCircle className="h-5 w-5" /> : <Circle className="h-5 w-5" />}
                        </button>
                      )}
                    </motion.div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  );
}
