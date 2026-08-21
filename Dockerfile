# syntax=docker/dockerfile:1
# Muse Discord music bot — Railway template
#
# Muse is a long-running Discord bot with no HTTP interface. Railway requires a
# reachable HTTP healthcheck, so this image wraps the upstream release with a
# small Node.js health sidecar listening on $PORT.
#
# Storage: Muse uses SQLite (schema.prisma -> provider = "sqlite") with the
# database and media cache living under $DATA_DIR. Attach a Railway Volume at
# /data to persist them. A docker VOLUME instruction is deliberately NOT used:
# the Railway builder rejects it ("docker VOLUME ... is not supported").

FROM ghcr.io/museofficial/muse:2.11.7-yt-dlp

# Upstream image sets WORKDIR /usr/app; dist/ and node_modules resolve from there.
WORKDIR /usr/app

ENV PORT=8080 \
    DATA_DIR=/data \
    NODE_ENV=production \
    BOT_PID_FILE=/tmp/muse-bot.pid

# Health sidecar + entrypoint. No extra apt packages are needed: liveness is
# probed in-process via process.kill(pid, 0) rather than shelling out to pgrep,
# which is not present in the node:22-bookworm-slim base.
COPY health-server.js /usr/local/bin/health-server.js
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/health-server.js \
 && mkdir -p /data

EXPOSE 8080

# tini is provided by the upstream base image and reaps the bot + sidecar.
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
