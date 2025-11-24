import { useLibraryStore, type LibraryBook } from "../stores/libraryStore";
import { usePlayer } from "../providers/PlayerContext";
import { useChaptersQuery } from "../hooks/useChaptersQuery";
import { Card } from "./ui/Card";
import { Button } from "./ui/Button";
import { Badge } from "./ui/Badge";
import { Play, Pause, Trash2, BookOpen } from "lucide-react";
import { useState } from "react";

export function LibraryCard({ book, onClick }: { book: LibraryBook; onClick: () => void }) {
    const removeBook = useLibraryStore((state) => state.removeBook);
    const { play, pause, isPlaying, currentBook } = usePlayer();
    const { data: chapters } = useChaptersQuery(book.id);
    const [isRemoving, setIsRemoving] = useState(false);

    const isCurrentBook = currentBook?.id === book.id;
    const completedCount = Object.keys(book.completedChapters).length;
    const totalChapters = chapters?.length || 0;
    const progress = totalChapters > 0 ? Math.round((completedCount / totalChapters) * 100) : 0;

    const handlePlay = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (isCurrentBook && isPlaying) {
            pause();
        } else {
            if (!chapters || chapters.length === 0) return;
            // Find first uncompleted chapter
            const firstUncompleted = chapters.find((ch) => !book.completedChapters[ch.id]);
            const chapterToPlay = firstUncompleted || chapters[0];
            play(book, chapterToPlay, chapters);
        }
    };

    const handleRemove = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (confirm(`確定要移除《${book.title}》嗎？`)) {
            setIsRemoving(true);
            // Small delay to allow animation if we added one, but for now just remove
            setTimeout(() => {
                removeBook(book.id);
            }, 200);
        }
    };

    return (
        <Card
            className={`group relative overflow-hidden border-white/5 bg-surface/40 transition-all hover:bg-surface/60 cursor-pointer ${isRemoving ? "opacity-0 scale-95" : "opacity-100 scale-100"}`}
            onClick={onClick}
        >
            <div className="flex gap-4">
                {/* Cover */}
                <div className="relative h-24 w-16 flex-shrink-0 overflow-hidden rounded-md bg-surface-active/50 shadow-md">
                    {book.coverUrl ? (
                        <img src={book.coverUrl} alt={book.title} className="h-full w-full object-cover" />
                    ) : (
                        <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                            <BookOpen className="h-6 w-6 opacity-20" />
                        </div>
                    )}

                    {/* Play Overlay on Cover */}
                    <div className={`absolute inset-0 flex items-center justify-center bg-black/40 transition-opacity ${isCurrentBook && isPlaying ? "opacity-100" : "opacity-0 group-hover:opacity-100"}`}>
                        <button
                            onClick={handlePlay}
                            className="rounded-full bg-white/20 p-1.5 text-white backdrop-blur-sm hover:bg-white/30 hover:scale-105 transition-all"
                        >
                            {isCurrentBook && isPlaying ? <Pause className="h-4 w-4 fill-current" /> : <Play className="h-4 w-4 fill-current ml-0.5" />}
                        </button>
                    </div>
                </div>

                {/* Content */}
                <div className="flex flex-1 flex-col justify-between py-1">
                    <div>
                        <h3 className="line-clamp-1 font-semibold text-white group-hover:text-primary transition-colors">{book.title}</h3>
                        <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                            <Badge variant="outline" className="h-5 px-1.5 font-normal text-[10px]">
                                {progress}% 完成
                            </Badge>
                            <span>{completedCount}/{totalChapters} 章</span>
                        </div>
                    </div>

                    <div className="flex items-center justify-between">
                        {/* Progress Bar */}
                        <div className="h-1 flex-1 overflow-hidden rounded-full bg-surface-active">
                            <div
                                className="h-full bg-primary transition-all duration-500"
                                style={{ width: `${progress}%` }}
                            />
                        </div>

                        <Button
                            variant="ghost"
                            size="icon"
                            className="ml-2 h-7 w-7 text-muted-foreground hover:text-red-400 hover:bg-red-500/10"
                            onClick={handleRemove}
                            title="移除書籍"
                        >
                            <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                    </div>
                </div>
            </div>
        </Card>
    );
}
