import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  },
  build: {
    outDir: path.resolve(__dirname, "../priv/static/client"),
    emptyOutDir: true,
    sourcemap: true,
    lib: {
      entry: path.resolve(__dirname, "src/main.tsx"),
      formats: ["es"],
      fileName: () => "client-app.js",
    },
  },
});
