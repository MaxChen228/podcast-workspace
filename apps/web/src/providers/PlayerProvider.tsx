import {
    useEffect,
    useRef,
    useState,
    type ReactNode,
} from "react";
import type { BookItem, ChapterItem } from "../types/api";
import { useServerConfig } from "./ServerConfigProvider";
import { PlayerContext, type PlayerState } from "./PlayerContext";

export function PlayerProvider({ children }: { children: ReactNode }) {
    const audioRef = useRef<HTMLAudioElement | null>(null);
    const { apiBaseUrl } = useServerConfig();

    const [state, setState] = useState<PlayerState>({
        isPlaying: false,
        currentBook: null,
        currentChapter: null,
        currentTime: 0,
        duration: 0,
        volume: 1,
        playbackRate: 1,
    });

    const [playlist, setPlaylist] = useState<ChapterItem[]>([]);

    // Initialize audio element
    useEffect(() => {
        const audio = new Audio();
        audioRef.current = audio;

        const updateTime = () => {
            setState((prev) => ({ ...prev, currentTime: audio.currentTime }));
        };

        const updateDuration = () => {
            setState((prev) => ({ ...prev, duration: audio.duration }));
        };

        const handleEnded = () => {
            setState((prev) => ({ ...prev, isPlaying: false }));
            // Auto-play next could go here
        };

        audio.addEventListener("timeupdate", updateTime);
        audio.addEventListener("loadedmetadata", updateDuration);
        audio.addEventListener("ended", handleEnded);

        return () => {
            audio.removeEventListener("timeupdate", updateTime);
            audio.removeEventListener("loadedmetadata", updateDuration);
            audio.removeEventListener("ended", handleEnded);
            audio.pause();
            audioRef.current = null;
        };
    }, []);

    const play = (book: BookItem, chapter: ChapterItem, newPlaylist?: ChapterItem[]) => {
        if (!audioRef.current || !apiBaseUrl) return;

        const audioUrl = `${apiBaseUrl}/books/${book.id}/chapters/${chapter.id}/audio`;

        // If playing the same track, just toggle
        if (state.currentBook?.id === book.id && state.currentChapter?.id === chapter.id) {
            resume();
            return;
        }

        audioRef.current.src = audioUrl;
        audioRef.current.load();
        audioRef.current.play().catch(console.error);

        if (newPlaylist) {
            setPlaylist(newPlaylist);
        }

        setState((prev) => ({
            ...prev,
            isPlaying: true,
            currentBook: book,
            currentChapter: chapter,
        }));
    };

    const pause = () => {
        audioRef.current?.pause();
        setState((prev) => ({ ...prev, isPlaying: false }));
    };

    const resume = () => {
        audioRef.current?.play().catch(console.error);
        setState((prev) => ({ ...prev, isPlaying: true }));
    };

    const seek = (time: number) => {
        if (audioRef.current) {
            audioRef.current.currentTime = time;
            setState((prev) => ({ ...prev, currentTime: time }));
        }
    };

    const setVolume = (volume: number) => {
        if (audioRef.current) {
            audioRef.current.volume = volume;
            setState((prev) => ({ ...prev, volume }));
        }
    };

    const setPlaybackRate = (rate: number) => {
        if (audioRef.current) {
            audioRef.current.playbackRate = rate;
            setState((prev) => ({ ...prev, playbackRate: rate }));
        }
    };

    const playNext = () => {
        if (!state.currentChapter || playlist.length === 0 || !state.currentBook) return;
        const currentIndex = playlist.findIndex((c) => c.id === state.currentChapter?.id);
        if (currentIndex !== -1 && currentIndex < playlist.length - 1) {
            play(state.currentBook, playlist[currentIndex + 1]);
        }
    };

    const playPrevious = () => {
        if (!state.currentChapter || playlist.length === 0 || !state.currentBook) return;
        const currentIndex = playlist.findIndex((c) => c.id === state.currentChapter?.id);
        if (currentIndex > 0) {
            play(state.currentBook, playlist[currentIndex - 1]);
        }
    };

    return (
        <PlayerContext.Provider
            value={{
                ...state,
                play,
                pause,
                resume,
                seek,
                setVolume,
                setPlaybackRate,
                playNext,
                playPrevious,
                setPlaylist,
            }}
        >
            {children}
        </PlayerContext.Provider>
    );
}
