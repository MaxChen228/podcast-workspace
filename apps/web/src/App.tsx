import { useState } from "react";
import { StorePage } from "./pages/StorePage";
import { LibraryPage } from "./pages/LibraryPage";
import { ServerSettingsPanel } from "./components/ServerSettingsPanel";
import { useServerConfig } from "./providers/ServerConfigProvider";
import { PlayerProvider } from "./providers/PlayerProvider";
import { AudioPlayer } from "./components/AudioPlayer";
import { SubtitleOverlay } from "./components/SubtitleOverlay";

export default function App() {
  const [activeTab, setActiveTab] = useState<"store" | "library">("store");
  const [showSettings, setShowSettings] = useState(false);
  const { apiBaseUrl } = useServerConfig();

  return (
    <PlayerProvider>
      <div className="app-shell">
        <header className="topbar">
          <div>
            <p className="muted">AI Podcast Workspace</p>
            <h1>Storytelling Web</h1>
          </div>
          <div className="topbar-actions">
            <div className="tabs" role="tablist">
              <button
                role="tab"
                className={activeTab === "store" ? "active" : ""}
                onClick={() => setActiveTab("store")}
              >
                書城
              </button>
              <button
                role="tab"
                className={activeTab === "library" ? "active" : ""}
                onClick={() => setActiveTab("library")}
              >
                書庫
              </button>
            </div>
            <button className="ghost" onClick={() => setShowSettings(true)}>
              Server Settings
            </button>
          </div>
        </header>
        <section className="status-bar">當前後端：{apiBaseUrl || "尚未設定"}</section>
        <main>{activeTab === "store" ? <StorePage /> : <LibraryPage />}</main>
        {showSettings && <ServerSettingsPanel onClose={() => setShowSettings(false)} />}
        <SubtitleOverlay />
        <AudioPlayer />
      </div>
    </PlayerProvider>
  );
}
