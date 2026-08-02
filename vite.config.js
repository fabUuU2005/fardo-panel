import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  // GitHub Pages publica los repositorios de proyecto dentro de /nombre-del-repositorio/.
  base: process.env.GITHUB_ACTIONS ? '/fardo-panel/' : '/',
  plugins: [react(), tailwindcss()],
})
