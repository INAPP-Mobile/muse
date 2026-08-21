#!/usr/bin/env node
/**
 * Health-check sidecar for the Muse Discord bot.
 *
 * Muse is a long-running Discord bot with no HTTP interface, but Railway
 * requires an HTTP endpoint to consider a deployment healthy. This sidecar
 * exposes /health on $PORT.
 *
 * Design notes:
 *  - Always answers 200 so a misconfigured bot (e.g. a bad DISCORD_TOKEN)
 *    does not turn into an endless Railway crash-loop. The JSON body carries
 *    the real bot state so operators can see it, and the container logs spell
 *    out exactly which variable is missing.
 *  - Bot liveness is probed with process.kill(pid, 0) against the PID written
 *    by entrypoint.sh. `pgrep` is deliberately NOT used: it is absent from the
 *    upstream node:22-bookworm-slim base image.
 */
const http = require('http');
const fs = require('fs');

const PORT = Number(process.env.PORT) || 8080;
const BOT_PID_FILE = process.env.BOT_PID_FILE || '/tmp/muse-bot.pid';

function readBotPid() {
  try {
    const raw = fs.readFileSync(BOT_PID_FILE, 'utf8').trim();
    const pid = Number.parseInt(raw, 10);
    return Number.isFinite(pid) && pid > 0 ? pid : null;
  } catch {
    return null;
  }
}

function isBotRunning() {
  const pid = readBotPid();
  if (pid === null) {
    return false;
  }

  try {
    process.kill(pid, 0); // signal 0 only tests for existence
    return true;
  } catch {
    return false;
  }
}

const startedAt = Date.now();

const server = http.createServer((req, res) => {
  const url = (req.url || '/').split('?')[0];

  if (url === '/health' || url === '/healthz' || url === '/') {
    const botRunning = isBotRunning();
    const body = {
      status: botRunning ? 'ok' : 'degraded',
      service: 'muse',
      bot: botRunning ? 'running' : 'stopped',
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
    };

    if (!botRunning) {
      body.hint = 'Bot process is not running. Check deploy logs and confirm DISCORD_TOKEN, DISCORD_CLIENT_ID and YOUTUBE_API_KEY are set.';
    }

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'not_found' }));
});

server.listen(PORT, '::', () => {
  console.log(`[health-server] Listening on port ${PORT}`);
});

server.on('error', (err) => {
  console.error(`[health-server] Failed to bind port ${PORT}: ${err.message}`);
  process.exit(1);
});

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`[health-server] Received ${signal}, shutting down`);
    server.close(() => process.exit(0));
  });
}
