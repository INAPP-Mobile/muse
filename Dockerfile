# syntax=docker/dockerfile:1
# Muse Discord music bot — Railway template
# 
# Muse is a long-running bot with no HTTP interface. This template wraps
# the upstream image with a Node.js health sidecar so Railway can monitor
# liveness on PORT 8080.

FROM ghcr.io/museofficial/muse:2.11.7-yt-dlp

ENV PORT=8080 \
    DATA_DIR=/data \
    NODE_ENV=production

# Install curl for HEALTHCHECK
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Health-check sidecar (Node.js already present in base image)
COPY health-server.js /usr/local/bin/health-server.js
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/health-server.js

# Persistent volume for bot data (cache, config, db)
VOLUME ["/data"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8080/health -o /dev/null || exit 1

# Use tini as init (already in base image) + custom entrypoint
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
