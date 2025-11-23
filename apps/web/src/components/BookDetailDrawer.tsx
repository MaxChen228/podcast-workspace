import type { BookItem, ChapterItem } from "../types/api";
import { usePlayer } from "../providers/PlayerProvider";

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

  const handlePlay = (chapter: ChapterItem) => {
    if (currentChapter?.id === chapter.id) {
      if (isPlaying) pause();
      else resume();
    } else {
      play(book, chapter);
    }
  };

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <div className="drawer" onClick={(e) => e.stopPropagation()}>
        <header className="drawer-header">
          <h2>{book.title}</h2>
          <button className="ghost" onClick={onClose}>
            關閉
          </button>
        </header>

        <div className="drawer-content">
          <div className="book-info">
            {book.cover_url && (
              <img src={book.cover_url} alt={book.title} className="book-cover-large" />
            )}
            <div className="actions">
              <button className="primary" onClick={onAddToLibrary} disabled={isInLibrary}>
                {isInLibrary ? "已加入書庫" : "加入書庫"}
              </button>
            </div>
          </div>

          <div className="chapters-list">
            <h3>章節列表 ({chapters?.length ?? 0})</h3>
            {isLoading && <p>載入中…</p>}
            {!isLoading && (!chapters || chapters.length === 0) && <p>尚未有章節</p>}

            <div className="stack">
              {chapters?.map((chapter) => {
                const isCurrent = currentChapter?.id === chapter.id;
                const isCompleted = completedChapters[chapter.id];

                return (
                  <div
                    key={chapter.id}
                    className={`chapter-item ${isCurrent ? "active-chapter" : ""}`}
                  >
                    <div className="chapter-main">
                      <button
                        className={`play-icon-btn ${isCurrent && isPlaying ? "playing" : ""}`}
                        onClick={() => handlePlay(chapter)}
                        title={isCurrent && isPlaying ? "暫停" : "播放"}
                      >
                        {isCurrent && isPlaying ? "⏸" : "▶"}
                      </button>
                      <div className="chapter-info">
                        <h4>{chapter.title}</h4>
                        <div className="meta">
                          {chapter.audio_duration_sec && (
                            <span>{Math.floor(chapter.audio_duration_sec / 60)} 分鐘</span>
                          )}
                          {chapter.word_count && <span>{chapter.word_count} 字</span>}
                        </div>
                      </div>
                    </div>

                    {isInLibrary && (
                      <label className="checkbox-label">
                        <input
                          type="checkbox"
                          checked={isCompleted}
                          onChange={() => onToggleChapter(chapter.id)}
                        />
                        已讀
                      </label>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
