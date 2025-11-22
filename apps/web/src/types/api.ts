export interface BookItem {
  id: string;
  title: string;
  cover_url?: string;
}

export interface ChapterItem {
  id: string;
  title: string;
  chapter_number?: number;
  audio_available: boolean;
  subtitles_available: boolean;
  word_count?: number;
  audio_duration_sec?: number;
  words_per_minute?: number;
}
