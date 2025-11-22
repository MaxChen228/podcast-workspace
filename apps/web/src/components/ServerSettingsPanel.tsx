import { useState } from "react";
import { useServerConfig } from "../providers/ServerConfigProvider";

interface Props {
  onClose: () => void;
}

export function ServerSettingsPanel({ onClose }: Props) {
  const { apiBaseUrl, history, setApiBaseUrl, removeServerUrl } = useServerConfig();
  const [value, setValue] = useState(apiBaseUrl);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    if (!value.trim()) {
      setError("請輸入有效的 URL");
      return;
    }
    setApiBaseUrl(value.trim());
    setError(null);
    onClose();
  };

  return (
    <div className="overlay" role="dialog" aria-modal="true">
      <div className="panel">
        <div className="panel-header">
          <h2>伺服器設定</h2>
          <button className="ghost" onClick={onClose} aria-label="關閉設定">
            ✕
          </button>
        </div>
        <form className="form" onSubmit={handleSubmit}>
          <label htmlFor="server-url">後端 API URL</label>
          <input
            id="server-url"
            name="server-url"
            value={value}
            onChange={(event) => setValue(event.target.value)}
            placeholder="例如 http://localhost:8000"
          />
          {error && <p className="error">{error}</p>}
          <button type="submit">儲存並套用</button>
        </form>
        <section>
          <h3>最近使用</h3>
          {history.length === 0 && <p className="muted">尚未有紀錄</p>}
          <ul className="history-list">
            {history.map((item) => (
              <li key={item}>
                <button
                  className={`ghost ${item === apiBaseUrl ? "active" : ""}`}
                  type="button"
                  onClick={() => setApiBaseUrl(item)}
                >
                  {item}
                </button>
                {history.length > 1 && (
                  <button className="ghost danger" type="button" onClick={() => removeServerUrl(item)}>
                    移除
                  </button>
                )}
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}
