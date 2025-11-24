import { useState } from "react";
import { useServerConfig } from "../providers/ServerConfigProvider";
import { X, History, Server, Trash2 } from "lucide-react";
import { Button } from "./ui/Button";
import { motion } from "framer-motion";

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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-md overflow-hidden rounded-xl border border-white/10 bg-surface shadow-2xl"
      >
        <div className="flex items-center justify-between border-b border-white/5 p-4">
          <div className="flex items-center gap-2">
            <Server className="h-5 w-5 text-primary" />
            <h2 className="text-lg font-semibold text-white">伺服器設定</h2>
          </div>
          <Button variant="ghost" size="icon" onClick={onClose}>
            <X className="h-5 w-5" />
          </Button>
        </div>

        <div className="p-4">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="server-url" className="text-sm font-medium text-muted-foreground">
                後端 API URL
              </label>
              <input
                id="server-url"
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder="例如 http://localhost:8000"
                className="flex h-10 w-full rounded-md border border-white/10 bg-surface-active/50 px-3 py-2 text-sm text-white placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
              />
              {error && <p className="text-sm text-red-400">{error}</p>}
            </div>
            <Button type="submit" className="w-full">
              儲存並套用
            </Button>
          </form>

          <div className="mt-6 space-y-4">
            <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <History className="h-4 w-4" />
              <h3>最近使用</h3>
            </div>

            {history.length === 0 ? (
              <p className="text-sm text-muted-foreground/50">尚未有紀錄</p>
            ) : (
              <ul className="space-y-2">
                {history.map((item) => (
                  <li key={item} className="group flex items-center justify-between rounded-lg border border-white/5 bg-surface/50 p-2 transition-colors hover:bg-surface-hover">
                    <button
                      className={`flex-1 text-left text-sm ${item === apiBaseUrl ? "font-medium text-primary" : "text-muted-foreground group-hover:text-white"}`}
                      type="button"
                      onClick={() => setApiBaseUrl(item)}
                    >
                      {item}
                    </button>
                    {history.length > 1 && (
                      <button
                        className="ml-2 rounded-md p-1 text-muted-foreground opacity-0 hover:bg-red-500/10 hover:text-red-400 group-hover:opacity-100 transition-all"
                        type="button"
                        onClick={() => removeServerUrl(item)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  );
}
