import { execSync } from 'node:child_process'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Stamp every build with its git commit + build date so a running
// deployment is traceable to an exact commit (shown next to APP_VERSION
// in the footers). On Vercel the SHA comes from the build env; locally
// from git; 'dev' if neither is available.
const commit =
  process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ??
  (() => {
    try { return execSync('git rev-parse --short HEAD').toString().trim() } catch { return 'dev' }
  })()
const builtAt = new Date().toISOString().slice(0, 10)

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  define: {
    __APP_COMMIT__: JSON.stringify(commit),
    __APP_BUILT__: JSON.stringify(builtAt),
  },
})
