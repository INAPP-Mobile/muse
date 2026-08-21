#!/bin/bash
# Entrypoint for the Muse Discord bot on Railway.
#
# Order of operations:
#   1. Validate required configuration and warn loudly about anything missing.
#   2. Start the health-check sidecar so Railway's healthcheck can pass.
#   3. Start the bot (Prisma migrations run inside migrate-and-start.js).
#
# The health sidecar intentionally outlives a crashed bot: Railway needs a
# reachable HTTP endpoint, and a hard failure here would produce a crash-loop
# that hides the real configuration error from the deploy logs.

set -uo pipefail

DATA_DIR="${DATA_DIR:-/data}"
PORT="${PORT:-8080}"
BOT_PID_FILE="${BOT_PID_FILE:-/tmp/muse-bot.pid}"
export DATA_DIR PORT BOT_PID_FILE

mkdir -p "${DATA_DIR}"

# ---------------------------------------------------------------------------
# Configuration validation
# ---------------------------------------------------------------------------
missing=()
for var in DISCORD_TOKEN DISCORD_CLIENT_ID; do
  if [ -z "${!var:-}" ]; then
    missing+=("${var}")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "[entrypoint] ============================================================"
  echo "[entrypoint] MISSING REQUIRED CONFIGURATION: ${missing[*]}"
  echo "[entrypoint] Muse cannot connect to Discord without these variables."
  echo "[entrypoint] Set them in the Railway service Variables tab, then redeploy."
  echo "[entrypoint] Create a bot application at https://discord.com/developers/applications"
  echo "[entrypoint] The health endpoint stays up so this message remains visible."
  echo "[entrypoint] ============================================================"
fi

if [ -z "${YOUTUBE_API_KEY:-}" ]; then
  echo "[entrypoint] WARNING: YOUTUBE_API_KEY is not set — YouTube search will be unavailable."
fi

# ---------------------------------------------------------------------------
# Health sidecar
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting health-check sidecar on port ${PORT}..."
node /usr/local/bin/health-server.js &
HEALTH_PID=$!

# Wait for the sidecar to actually bind the port before doing anything else.
for _ in $(seq 1 20); do
  if ! kill -0 "${HEALTH_PID}" 2>/dev/null; then
    echo "[entrypoint] ERROR: health sidecar exited during startup"
    exit 1
  fi
  if node -e "require('net').connect(${PORT},'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
echo "[entrypoint] Health server ready (PID ${HEALTH_PID})"

# ---------------------------------------------------------------------------
# Bot
# ---------------------------------------------------------------------------
if [ "${#missing[@]}" -gt 0 ]; then
  echo "[entrypoint] Skipping bot startup until required variables are set."
else
  echo "[entrypoint] Starting Muse bot (applying Prisma migrations first)..."
  node --enable-source-maps dist/scripts/migrate-and-start.js &
  BOT_PID=$!
  echo "${BOT_PID}" > "${BOT_PID_FILE}"
  echo "[entrypoint] Muse bot started (PID ${BOT_PID})"
fi

shutdown() {
  echo "[entrypoint] Received shutdown signal, stopping processes..."
  [ -n "${BOT_PID:-}" ] && kill "${BOT_PID}" 2>/dev/null
  kill "${HEALTH_PID}" 2>/dev/null
  wait
  exit 0
}
trap shutdown SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Supervise
# ---------------------------------------------------------------------------
while true; do
  if [ -n "${BOT_PID:-}" ] && ! kill -0 "${BOT_PID}" 2>/dev/null; then
    wait "${BOT_PID}" 2>/dev/null
    bot_exit=$?
    echo "[entrypoint] Bot process exited with code ${bot_exit}."
    echo "[entrypoint] Review the logs above for the cause (bad token, Discord API error, migration failure)."
    rm -f "${BOT_PID_FILE}"
    BOT_PID=""
  fi

  if ! kill -0 "${HEALTH_PID}" 2>/dev/null; then
    echo "[entrypoint] Health server died, restarting..."
    node /usr/local/bin/health-server.js &
    HEALTH_PID=$!
  fi

  sleep 5
done
