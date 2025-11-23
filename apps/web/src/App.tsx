import { useState } from "react";
import { StorePage } from "./pages/StorePage";
import { LibraryPage } from "./pages/LibraryPage";
import { ServerSettingsPanel } from "./components/ServerSettingsPanel";
import { PlayerProvider } from "./providers/PlayerProvider";
import { AudioPlayer } from "./components/AudioPlayer";
import { SubtitleOverlay } from "./components/SubtitleOverlay";
import { Header } from "./components/Header";

export default function App() {
  const [activeTab, setActiveTab] = useState<"store" | "library">("store");
  const [showSettings, setShowSettings] = useState(false);

  return (
    <PlayerProvider>
      <div className="min-h-screen bg-background text-text selection:bg-primary selection:text-white">
        <Header
          activeTab={activeTab}
          onTabChange={setActiveTab}
          onOpenSettings={() => setShowSettings(true)}
        />

        <main className="mx-auto max-w-7xl px-4 pt-24 pb-32 sm:px-6 lg:px-8">
          {activeTab === "store" ? <StorePage /> : <LibraryPage />}
        </main>

        <SubtitleOverlay />
        <AudioPlayer />

        {showSettings && <ServerSettingsPanel onClose={() => setShowSettings(false)} />}
      </div>
    </PlayerProvider>
  );
}
