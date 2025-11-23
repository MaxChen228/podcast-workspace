import { usePlayer } from "../providers/PlayerContext";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Play, Pause, SkipBack, SkipForward, Volume2, Maximize2 } from "lucide-react";
import { Button } from "./ui/Button";

export function AudioPlayer() {
    const {
        currentBook,
        currentChapter,
        isPlaying,
        currentTime,
        duration,
        pause,
        resume,
        seek,
        playNext,
        playPrevious,
    } = usePlayer();

    const [isDragging, setIsDragging] = useState(false);
    const [localTime, setLocalTime] = useState(0);

    useEffect(() => {
        if (!isDragging) {
            setLocalTime(currentTime);
        }
    }, [currentTime, isDragging]);

    if (!currentBook || !currentChapter) return null;

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, "0")}`;
    };

    const handleSeekChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setLocalTime(Number(e.target.value));
    };

    const progressPercent = duration ? (localTime / duration) * 100 : 0;

    return (
        <AnimatePresence>
            <motion.div
                initial={{ y: 100, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={{ y: 100, opacity: 0 }}
                className="fixed bottom-6 left-4 right-4 z-50 mx-auto max-w-3xl"
            >
                <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-surface/90 p-4 shadow-2xl backdrop-blur-xl">
                    {/* Progress Bar Background */}
                    <div className="absolute bottom-0 left-0 h-1 w-full bg-white/5">
                        <div
                            className="h-full bg-primary transition-all duration-100 ease-linear"
                            style={{ width: `${progressPercent}%` }}
                        />
                    </div>

                    <div className="flex items-center gap-4">
                        {/* Cover Art */}
                        <div className="relative h-12 w-12 flex-shrink-0 overflow-hidden rounded-lg shadow-lg">
                            {currentBook.cover_url ? (
                                <img src={currentBook.cover_url} alt={currentBook.title} className="h-full w-full object-cover" />
                            ) : (
                                <div className="h-full w-full bg-surface-active" />
                            )}
                        </div>

                        {/* Info */}
                        <div className="min-w-0 flex-1">
                            <h3 className="truncate text-sm font-semibold text-white">{currentChapter.title}</h3>
                            <p className="truncate text-xs text-muted-foreground">{currentBook.title}</p>
                        </div>

                        {/* Controls */}
                        <div className="flex items-center gap-2">
                            <Button variant="ghost" size="icon" onClick={playPrevious} className="hidden sm:inline-flex">
                                <SkipBack className="h-5 w-5" />
                            </Button>

                            <Button
                                size="icon"
                                variant="primary"
                                className="h-10 w-10 rounded-full shadow-lg shadow-primary/25"
                                onClick={isPlaying ? pause : resume}
                            >
                                {isPlaying ? <Pause className="h-5 w-5 fill-current" /> : <Play className="h-5 w-5 fill-current ml-0.5" />}
                            </Button>

                            <Button variant="ghost" size="icon" onClick={playNext}>
                                <SkipForward className="h-5 w-5" />
                            </Button>
                        </div>

                        {/* Time & Extra */}
                        <div className="hidden items-center gap-4 sm:flex">
                            <span className="text-xs font-medium tabular-nums text-muted-foreground">
                                {formatTime(localTime)} / {formatTime(duration)}
                            </span>
                            <div className="h-4 w-px bg-white/10" />
                            <Button variant="ghost" size="icon" className="text-muted-foreground hover:text-white">
                                <Volume2 className="h-4 w-4" />
                            </Button>
                        </div>
                    </div>

                    {/* Invisible Range Input for Seeking */}
                    <input
                        type="range"
                        min={0}
                        max={duration || 100}
                        value={localTime}
                        onChange={handleSeekChange}
                        onMouseDown={() => setIsDragging(true)}
                        onMouseUp={() => {
                            seek(localTime);
                            setIsDragging(false);
                        }}
                        onTouchStart={() => setIsDragging(true)}
                        onTouchEnd={() => {
                            seek(localTime);
                            setIsDragging(false);
                        }}
                        className="absolute inset-0 z-10 h-full w-full cursor-pointer opacity-0"
                        aria-label="Seek"
                    />
                </div>
            </motion.div>
        </AnimatePresence>
    );
}
