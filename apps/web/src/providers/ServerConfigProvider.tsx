import React, { createContext, useContext, useEffect, useMemo, useState } from "react";

const STORAGE_KEY = "ps-web-server-config";
const DEFAULT_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

type ServerConfigState = {
  apiBaseUrl: string;
  history: string[];
};

type ServerConfigContextValue = ServerConfigState & {
  setApiBaseUrl: (url: string) => void;
  addServerUrl: (url: string) => void;
  removeServerUrl: (url: string) => void;
};

const ServerConfigContext = createContext<ServerConfigContextValue | undefined>(undefined);

function safeParse(value: string | null): ServerConfigState | undefined {
  if (!value) return undefined;
  try {
    const data = JSON.parse(value) as Partial<ServerConfigState>;
    if (typeof data.apiBaseUrl === "string" && Array.isArray(data.history)) {
      return {
        apiBaseUrl: data.apiBaseUrl,
        history: data.history.length ? data.history : [data.apiBaseUrl],
      };
    }
  } catch (error) {
    console.warn("Failed to parse server config from storage", error);
  }
  return undefined;
}

function normalizeUrl(url: string): string {
  try {
    const instance = new URL(url);
    return instance.origin;
  } catch {
    return url.trim();
  }
}

const defaultState: ServerConfigState = {
  apiBaseUrl: normalizeUrl(DEFAULT_URL),
  history: [normalizeUrl(DEFAULT_URL)],
};

export const ServerConfigProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const [state, setState] = useState<ServerConfigState>(() => {
    if (typeof window === "undefined") return defaultState;
    return safeParse(window.localStorage.getItem(STORAGE_KEY)) ?? defaultState;
  });

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [state]);

  const setApiBaseUrl = (url: string) => {
    const nextUrl = normalizeUrl(url);
    if (!nextUrl) return;
    setState((prev) => ({
      apiBaseUrl: nextUrl,
      history: prev.history.includes(nextUrl) ? prev.history : [nextUrl, ...prev.history].slice(0, 5),
    }));
  };

  const addServerUrl = (url: string) => {
    const nextUrl = normalizeUrl(url);
    if (!nextUrl) return;
    setState((prev) => ({
      apiBaseUrl: prev.apiBaseUrl,
      history: prev.history.includes(nextUrl) ? prev.history : [nextUrl, ...prev.history].slice(0, 5),
    }));
  };

  const removeServerUrl = (url: string) => {
    setState((prev) => {
      const filtered = prev.history.filter((item) => item !== url);
      if (!filtered.length) {
        return defaultState;
      }
      const apiBaseUrl = prev.apiBaseUrl === url ? filtered[0] : prev.apiBaseUrl;
      return { apiBaseUrl, history: filtered };
    });
  };

  const value = useMemo<ServerConfigContextValue>(
    () => ({
      apiBaseUrl: state.apiBaseUrl,
      history: state.history,
      setApiBaseUrl,
      addServerUrl,
      removeServerUrl,
    }),
    [state]
  );

  return <ServerConfigContext.Provider value={value}>{children}</ServerConfigContext.Provider>;
};

export function useServerConfig(): ServerConfigContextValue {
  const context = useContext(ServerConfigContext);
  if (!context) {
    throw new Error("useServerConfig must be used within ServerConfigProvider");
  }
  return context;
}
