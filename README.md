# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/wx22J0)

![Muse Discord Music Bot](https://raw.githubusercontent.com/INAPP-Mobile/muse/master/template-icon.svg)

Muse is a **highly-opinionated midwestern self-hosted Discord music bot that doesn't suck**. Built for small to medium-sized Discord servers, it supports livestreams, seeking, local caching, Spotify conversion, and multi-guild support — all from a single Railway service with a persistent volume.

## About Hosting

The template deploys a single service built from a Dockerfile based on the official `ghcr.io/museofficial/muse` image:

- **muse** — Discord music bot (TypeScript) with a built-in health-check sidecar on `PORT=8080`

Railway provides compute, TLS at the edge, a public URL, and a persistent volume at `/data` for bot cache, configuration, and database. The health sidecar exposes `/health` so Railway can monitor liveness even though the bot itself has no HTTP interface.

## Why Deploy

- **Zero-config Discord bot** — set your tokens and deploy; no manual server setup
- **Persistent storage** — bot cache, config, and database survive restarts on a Railway volume
- **Health monitoring** — built-in health sidecar means Railway can detect and restart a stuck bot
- **Multi-guild support** — one Muse instance serves multiple Discord servers
- **Spotify integration** — optional Spotify API keys enable automatic playlist/artist/album conversion
- **Livestreams & seeking** — full playback control including YouTube livestreams
- **No vote-to-skip** — this is anarchy, not a democracy

## Common Use Cases

- **Friend group server** — music bot for your Discord community without paying for premium bots
- **Multi-server host** — one deployment serves multiple guilds with isolated configs
- **Self-hosted alternative** — replace paid Discord music bots (Rythm, Groovy alternatives)
- **Development/testing** — run a bot instance for testing Discord integrations

## Dependencies for Muse

### Deployment Dependencies

| Dependency | Required | Description |
|------------|----------|-------------|
| Discord bot token | Yes | From [Discord Developer Portal](https://discord.com/developers/applications) |
| Discord client ID | Yes | Application ID from Developer Portal |
| Discord client secret | No | Used for optional OAuth2 invite link generation |
| YouTube API key | Yes | From [Google Cloud Console](https://console.developers.google.com/) |
| Spotify client ID | No | Enables Spotify URL conversion |
| Spotify client secret | No | Enables Spotify URL conversion |

## Quick Start

1. **Create a Discord application** at https://discord.com/developers/applications
2. **Get your bot token** from the Bot section of your application
3. **Get your client ID and secret** from the OAuth2 section
4. **Get a YouTube API key** from https://console.developers.google.com/ (enable YouTube Data API v3)
5. **Click Deploy on Railway** and fill in the required tokens
6. **Wait for provisioning** (~2-3 minutes for first build)
7. **Invite the bot** to your Discord server using the OAuth2 URL generator (scopes: `bot`, `applications.commands`; permissions: Connect, Speak, Send Messages)
8. **Use `/play <query>`** in a voice channel to start playing music

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Railway Service                  │
│                                                  │
│  ┌──────────────┐    ┌──────────────────────┐   │
│  │  Health Side │    │     Muse Bot          │   │
│  │  car (Node)  │    │  (TypeScript/Bot)     │   │
│  │  PORT 8080   │    │  No HTTP interface    │   │
│  │  /health     │    │  Long-running process │   │
│  └──────┬───────┘    └──────────────────────┘   │
│         │                                        │
│  ┌──────┴──────────────────────────────────┐    │
│  │         Persistent Volume (/data)        │    │
│  │  - Bot cache                             │    │
│  │  - Configuration                         │    │
│  │  - SQLite database                       │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Features

- **Livestreams** — play YouTube livestreams in your voice channel
- **Seeking** — skip to any position in a track
- **Local caching** — downloaded media cached on the persistent volume
- **No vote-to-skip** — skip immediately, no democracy
- **Spotify conversion** — auto-converts Spotify playlists, artists, albums, and songs
- **Favorite queries** — users can save favorite searches for reuse
- **Multi-guild** — one instance supports multiple Discord servers
- **Volume controls** — configurable volume with optional ducking when people speak
- **SponsorBlock** — optionally skip sponsored segments (enable with `ENABLE_SPONSORBLOCK=true`)

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DISCORD_TOKEN` | Yes | — | Discord bot token |
| `DISCORD_CLIENT_ID` | Yes | — | Discord application client ID |
| `DISCORD_CLIENT_SECRET` | Yes | — | Discord application client secret |
| `YOUTUBE_API_KEY` | Yes | — | YouTube Data API v3 key |
| `SPOTIFY_CLIENT_ID` | No | — | Spotify API client ID |
| `SPOTIFY_CLIENT_SECRET` | No | — | Spotify API client secret |
| `BOT_STATUS` | No | `online` | Bot status (online/dnd/idle/invisible) |
| `BOT_ACTIVITY_TYPE` | No | `LISTENING` | Activity type (PLAYING/STREAMING/LISTENING/WATCHING/COMPETING) |
| `BOT_ACTIVITY` | No | `music 🎵` | Activity text shown in sidebar |
| `DATA_DIR` | No | `/data` | Data directory for cache and config |
| `TZ` | No | `UTC` | Container timezone (IANA) |
| `CACHE_LIMIT` | No | `2GB` | Max disk cache size |
| `YT_DLP_AUTO_UPDATE` | No | `true` | Auto-update yt-dlp on startup |
| `ENABLE_SPONSORBLOCK` | No | `false` | Skip sponsored segments |
| `PORT` | No | `8080` | Health sidecar port |

## Bot Commands

Once deployed and invited to your server, use these slash commands:

- `/play <query>` — play a song or add to queue
- `/skip` — skip the current track
- `/stop` — stop playback and clear queue
- `/queue` — view the current queue
- `/nowplaying` — see what's currently playing
- `/volume <0-100>` — set playback volume
- `/config set-reduce-vol-when-voice true/false` — toggle volume ducking
- `/favorites add <query>` — save a favorite search
- `/favorites play <name>` — play a saved favorite

## Volume & Ducking

Muse supports configurable volume with optional ducking (lowering music volume when someone speaks):

```
/config set-reduce-vol-when-voice true
/config set-reduce-vol-when-voice-target 20
```

The target (0-100) sets the volume level when voice activity is detected. Default is 20.

## Spotify Integration

To enable Spotify URL conversion (playlists, artists, albums), set these variables:

```
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

Get credentials at https://developer.spotify.com/dashboard by creating an app.

## Registering Commands

By default, Muse registers commands per-guild (instant). For bot-wide registration (takes up to 1 hour to propagate):

```
REGISTER_COMMANDS_ON_BOT=true
```

## Updating

To update Muse, redeploy on Railway. The build pulls the pinned image version. To update yt-dlp without a full rebuild, set `YT_DLP_AUTO_UPDATE=true` (default).

## Troubleshooting

- **Bot doesn't respond**: Check `DISCORD_TOKEN` is correct and bot has required permissions
- **No audio**: Ensure bot has Connect and Speak permissions in the voice channel
- **YouTube errors**: Verify `YOUTUBE_API_KEY` is valid and YouTube Data API v3 is enabled
- **Spotify not working**: Check `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are set correctly
- **Health check fails**: The bot may be crashing on startup — check logs in Railway dashboard
