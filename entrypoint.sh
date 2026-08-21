#!/bin/bash
# Entrypoint for Muse Discord bot on Railway
#
# Starts the health-check sidecar and the bot. If the bot crashes,
# the health server stays alive and returns 503 so Railway detects
# the failure and restarts the container.

set -e

# Start health-check sidecar in background (long-running)
echo "[entrypoint] Starting health-check sidecar on port ${PORT}..."
node /usr/local/bin/health-server.js &
HEALTH_PID=$!

# Give the health server a moment to bind
sleep 2

# Verify health server started
if ! kill -0 $HEALTH_PID 2>/dev/null; then
  echo "[entrypoint] ERROR: Health server failed to start"
  exit 1
fi
echo "[entrypoint] Health server started (PID: $HEALTH_PID)"

# Start the bot in background and track its PID
echo "[entrypoint] Starting Muse bot..."
node --enable-source-maps dist/scripts/migrate-and-start.js &
BOT_PID=$!

# Save bot PID for health check
echo $BOT_PID > /tmp/muse-bot.pid
echo "[entrypoint] Muse bot started (PID: $BOT_PID)"

# Monitor both processes
while true; do
  if ! kill -0 $BOT_PID 2>/dev/null; then
    echo "[entrypoint] Bot process exited, keeping health server alive for liveness detection..."
    # Keep health server running so Railway detects failure
    while kill -0 $HEALTH_PID 2>/dev/null; do
      sleep 5
    done
    echo "[entrypoint] Health server also exited"
    exit 1
  fi
  if ! kill -0 $HEALTH_PID 2>/dev/null; then
    echo "[entrypoint] Health server died, restarting..."
    node /usr/local/bin/health-server.js &
    HEALTH_PID=$!
    sleep 1
  fi
  sleep 1
done
