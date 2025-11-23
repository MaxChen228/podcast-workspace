import { usePlayer } from "../providers/PlayerProvider";
import { useEffect, useState } from "react";

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

    const handleSeekStart = () => setIsDragging(true);

    const handleSeekEnd = () => {
        seek(localTime);
        setIsDragging(false);
    };

    return (
        <div className="audio-player">
            <div className="player-track-info">
                {currentBook.cover_url && (
                    <img src={currentBook.cover_url} alt={currentBook.title} className="player-cover" />
                )}
                <div>
                    <div className="player-title">{currentChapter.title}</div>
                    <div className="player-subtitle">{currentBook.title}</div>
                </div>
            </div>

            <div className="player-controls-container">
                <div className="player-controls">
                    <button className="icon-btn" onClick={playPrevious} aria-label="Previous">
                        ⏮
                    </button>
                    <button
                        className="play-btn"
                        onClick={isPlaying ? pause : resume}
                        aria-label={isPlaying ? "Pause" : "Play"}
                    >
                        {isPlaying ? "⏸" : "▶"}
                    </button>
                    <button className="icon-btn" onClick={playNext} aria-label="Next">
                        ⏭
                    </button>
                </div>

                <div className="player-progress">
                    <span className="time-text">{formatTime(localTime)}</span>
                    <input
                        type="range"
                        min={0}
                        max={duration || 100}
                        value={localTime}
                        onChange={handleSeekChange}
                        onMouseDown={handleSeekStart}
                        onMouseUp={handleSeekEnd}
                        onTouchStart={handleSeekStart}
                        onTouchEnd={handleSeekEnd}
                        className="seek-slider"
                    />
                    <span className="time-text">{formatTime(duration)}</span>
                </div>
            </div>

            <div className="player-actions">
                {/* Placeholder for volume/speed */}
            </div>
        </div>
    );
}
