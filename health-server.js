#!/usr/bin/env node
/**
 * Minimal health-check HTTP server for Muse Discord bot.
 * 
 * Muse is a long-running bot process with no HTTP interface.
 * This sidecar exposes /health on PORT so Railway can monitor liveness.
 * 
 * Health logic: the bot process is considered healthy if it's running.
 * We check by looking for the bot PID file or by checking if the
 * main process is still alive.
 */
const http = require('http');
const { execSync } = require('child_process');
const fs = require('fs');

const PORT = process.env.PORT || 8080;
const BOT_PID_FILE = '/tmp/muse-bot.pid';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    try {
      // Check if bot process is alive
      let healthy = false;
      
      // Method 1: Check PID file
      if (fs.existsSync(BOT_PID_FILE)) {
        const pid = fs.readFileSync(BOT_PID_FILE, 'utf8').trim();
        try {
          process.kill(parseInt(pid), 0); // Signal 0 = check existence
          healthy = true;
        } catch (e) {
          healthy = false;
        }
      }
      
      // Method 2: Fallback - check if node process running
      if (!healthy) {
        try {
          const output = execSync('pgrep -f "dist/scripts/migrate-and-start" || true', { encoding: 'utf8' });
          healthy = output.trim().length > 0;
        } catch (e) {
          healthy = false;
        }
      }
      
      if (healthy) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', service: 'muse' }));
      } else {
        res.writeHead(503, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'unhealthy', service: 'muse' }));
      }
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'error', message: err.message }));
    }
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[health-server] Listening on port ${PORT}`);
});
