import { useEffect, useState } from "react";
import { usePlayer } from "../providers/PlayerProvider";
import { useServerConfig } from "../providers/ServerConfigProvider";

interface SubtitleItem {
    start: number;
    end: number;
    text: string;
    speaker?: string;
}

export function SubtitleOverlay() {
    const { currentBook, currentChapter, currentTime, isPlaying } = usePlayer();
    const { apiBaseUrl } = useServerConfig();
    const [subtitles, setSubtitles] = useState<SubtitleItem[]>([]);
    const [currentSubtitle, setCurrentSubtitle] = useState<SubtitleItem | null>(null);

    // Fetch subtitles when chapter changes
    useEffect(() => {
        if (!currentBook || !currentChapter || !apiBaseUrl) {
            setSubtitles([]);
            return;
        }

        const fetchSubtitles = async () => {
            try {
                const response = await fetch(
                    `${apiBaseUrl}/books/${currentBook.id}/chapters/${currentChapter.id}/subtitles`
                );
                if (response.ok) {
                    const data = await response.json();
                    // Assuming backend returns JSON format, if VTT we need parsing
                    // For now, let's assume the backend returns a list of {start, end, text}
                    // If the backend returns VTT text, we would need a parser.
                    // Let's assume JSON for now based on the project description "CLI... subtitles".
                    // If it fails, we might need to adjust.
                    setSubtitles(data as SubtitleItem[]);
                } else {
                    setSubtitles([]);
                }
            } catch (error) {
                console.error("Failed to load subtitles", error);
                setSubtitles([]);
            }
        };

        fetchSubtitles();
    }, [currentBook, currentChapter, apiBaseUrl]);

    // Sync subtitle with time
    useEffect(() => {
        if (!subtitles.length) {
            setCurrentSubtitle(null);
            return;
        }

        const match = subtitles.find(
            (sub) => currentTime >= sub.start && currentTime <= sub.end
        );
        setCurrentSubtitle(match || null);
    }, [currentTime, subtitles]);

    if (!currentSubtitle || !isPlaying) return null;

    return (
        <div className="subtitle-overlay">
            <div className="subtitle-content">
                {currentSubtitle.speaker && (
                    <span className="subtitle-speaker">{currentSubtitle.speaker}: </span>
                )}
                {currentSubtitle.text}
            </div>
        </div>
    );
}
