import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    // Vite's dev server binds to loopback-only by default, so it's
    // unreachable from outside its own container/network namespace even
    // with the port published -- Docker's port forwarding connects to the
    // container's external interface, not its loopback. Bind all
    // interfaces so `docker compose`'s published port (and other
    // containers) can actually reach it.
    host: true,
    proxy: {
      // This file runs under Node at dev-server startup, not in the browser
      // bundle, so the VITE_ env prefix requirement (for import.meta.env)
      // doesn't apply here. docker-compose sets API_PROXY_TARGET to the
      // backend service's compose DNS name; plain local `npm start` outside
      // Docker falls back to localhost.
      '/api': process.env.API_PROXY_TARGET || 'http://localhost:8080',
    },
  },
});
