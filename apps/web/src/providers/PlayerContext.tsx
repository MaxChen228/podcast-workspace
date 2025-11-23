import { createContext, useContext } from "react";
import type { BookItem, ChapterItem } from "../types/api";

export interface PlayerState {
    isPlaying: boolean;
    currentBook: BookItem | null;
    currentChapter: ChapterItem | null;
    currentTime: number;
    duration: number;
    volume: number;
    playbackRate: number;
}

export interface PlayerContextType extends PlayerState {
    play: (book: BookItem, chapter: ChapterItem, newPlaylist?: ChapterItem[]) => void;
    pause: () => void;
    resume: () => void;
    seek: (time: number) => void;
    setVolume: (volume: number) => void;
    setPlaybackRate: (rate: number) => void;
    playNext: () => void;
    playPrevious: () => void;
    setPlaylist: (chapters: ChapterItem[]) => void;
}

export const PlayerContext = createContext<PlayerContextType | null>(null);

export function usePlayer() {
    const context = useContext(PlayerContext);
    if (!context) {
        throw new Error("usePlayer must be used within a PlayerProvider");
    }
    return context;
}
