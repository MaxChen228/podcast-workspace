import type { BookItem, ChapterItem } from "../types/api";

interface Props {
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
}: Props) {
  return (
    <aside className="drawer" aria-label={`章節 - ${book.title}`}>
      <div className="drawer-header">
        <div>
          <p className="drawer-label">書籍</p>
          <h2>{book.title}</h2>
        </div>
        <button className="ghost" onClick={onClose} aria-label="關閉章節細節">
          ✕
        </button>
      </div>
      <div className="drawer-body">
        <p className="muted">共 {chapters?.length ?? 0} 個章節</p>
        <button className="primary" onClick={onAddToLibrary} disabled={isInLibrary}>
          {isInLibrary ? "已在我的書庫" : "加入我的書庫"}
        </button>
        <div className="chapter-list">
          {isLoading && <p>載入章節中…</p>}
          {!isLoading && (!chapters || chapters.length === 0) && <p className="muted">尚未有章節</p>}
          {chapters?.map((chapter) => (
            <article key={chapter.id} className="chapter-card">
              <div>
                <p className="chapter-title">
                  {chapter.chapter_number !== undefined && <strong>#{chapter.chapter_number} </strong>}
                  {chapter.title}
                </p>
                <p className="muted stats">
                  {chapter.word_count ? `${chapter.word_count} 字` : "-"} ·
                  {chapter.audio_duration_sec ? ` ${Math.round(chapter.audio_duration_sec / 60)} 分` : " 無音訊"} ·
                  {chapter.words_per_minute ? ` ${chapter.words_per_minute} WPM` : ""}
                </p>
              </div>
              <label className="toggle">
                <input
                  type="checkbox"
                  checked={Boolean(completedChapters[chapter.id])}
                  onChange={() => onToggleChapter(chapter.id)}
                />
                <span>完成</span>
              </label>
            </article>
          ))}
        </div>
      </div>
    </aside>
  );
}
