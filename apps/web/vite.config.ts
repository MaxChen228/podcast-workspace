import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "VITE_");

  return {
    plugins: [react()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "src"),
      },
    },
    server: {
      port: 5173,
      strictPort: true,
      host: "0.0.0.0",
    },
    define: {
      __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
      __API_BASE_URL__: JSON.stringify(env.VITE_API_BASE_URL ?? ""),
    },
  };
});
