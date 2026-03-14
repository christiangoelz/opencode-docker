# OpenCode Docker — Isolated Development Environment

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange.svg)](https://ubuntu.com/)

Run [OpenCode](https://opencode.ai/) inside a Docker container so it can only touch your project files — not your SSH keys, not your home directory, not your system. Supports 75+ AI providers including Claude, GPT, Gemini, Groq, and local models via Ollama.

---

## Table of Contents

- [Why This Matters](#why-this-matters)
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [Sessions & Memory](#sessions--memory)
- [Configure Providers](#configure-providers)
- [Configuration Reference](#configuration-reference)
- [Security](#security)
- [Tips & Recipes](#tips--recipes)
- [Cleanup](#cleanup)
- [Project Structure](#project-structure)

---

## Why This Matters

Running AI coding agents with full permissions on your host system poses risks:
- Accidental access to sensitive files (SSH keys, credentials, personal data)
- Unintended system modifications
- Lack of reproducible development environments

This Docker setup provides:
- **File system isolation** — agent only sees the mounted workspace directory
- **No host file access** — SSH keys, home directory, and system files are protected
- **Persistent memory** — auth tokens and session history survive container restarts
- **Easy reset** — destroy and rebuild anytime without affecting your system
- **Reproducible environment** — same setup across different machines
- **Non-root execution** — runs as unprivileged user inside container

---

## Quick Start

### Prerequisites

- Docker Engine 20.10+ and Docker Compose 2.0+
- At least **one** of: Anthropic, OpenAI, Gemini, Groq, OpenRouter API key/subscription, or local Ollama

### Step 1: Clone and build

```bash
git clone <repository-url>
cd opencode-docker
./scripts/setup.sh
```

### Step 2: Start the container

```bash
./scripts/run.sh
```

This drops you into a shell inside the container. Your project files are at `/workspace`.

### Step 3: Authenticate

**Option A — OAuth (recommended for Claude Pro/Max subscribers):**

```bash
# Inside the container:
opencode auth login
```

A URL is printed. Open it in your browser, log in, and you're done. Your token is saved to `./data/share/auth.json` on the host and **persists across container restarts** — you only need to do this once.

**Option B — API key:**

```bash
# On the host, edit .env and add your key:
ANTHROPIC_API_KEY=sk-ant-...
```

Restart the container and the key is automatically available inside.

### Step 4: Start coding

```bash
# Inside the container:
opencode
```

OpenCode opens its TUI. Select a model and start chatting.

---

## Authentication

### OAuth Login (Claude Pro/Max and similar subscriptions)

OAuth lets you use your subscription credits instead of per-token API billing.

```bash
# Inside the container:
opencode auth login
```

The token is stored in `./data/share/auth.json` (bind-mounted to `/home/opencode/.local/share/opencode/auth.json` inside the container). It survives `docker stop` / `docker start` and container recreation.

To check your current auth status:

```bash
# Inside the container:
opencode auth
```

To log out:

```bash
opencode auth logout
```

### API Keys

Set one or more keys in `.env` on the host (copy from `.env.example`):

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
GROQ_API_KEY=gsk_...
OPENROUTER_API_KEY=sk-or-...
GITHUB_TOKEN=ghp_...
```

Keys are injected as environment variables every time the container starts. No rebuild needed.

---

## Sessions & Memory

### How memory works

OpenCode stores all conversation history, sessions, and state in a SQLite database. In this Docker setup everything lives under `./data/share/` on the **host** (outside the container), so it is fully persistent across restarts.

> **Important distinction:** The container has two separate bind mounts:
> - `./workspace/` → `/workspace` — your **project files** (what the agent edits)
> - `./data/share/` → `/home/opencode/.local/share/opencode/` — opencode's **persistent data** (auth, sessions, logs)
>
> Even though the container's working directory is `/workspace`, opencode writes all its own state to the second mount. The two are completely independent. Stopping or recreating the container affects neither.

```
data/                               ← lives on the HOST, never inside the container image
└── share/                          ← mounted to ~/.local/share/opencode/ inside container
    ├── auth.json                   ← OAuth tokens (survives restarts)
    ├── opencode.db                 ← all sessions, messages, and project state
    ├── opencode.db-shm             ← SQLite WAL shared memory (auto-managed)
    ├── opencode.db-wal             ← SQLite write-ahead log (auto-managed)
    ├── log/                        ← timestamped log files (one per run, survive restarts)
    │   └── 2026-03-14T160557.log
    └── storage/
        ├── session/                ← per-session metadata
        ├── message/                ← message history
        └── part/                   ← message parts / tool outputs
```

Nothing is lost when you stop, restart, or recreate the container, **as long as you do not run `./scripts/cleanup.sh --full`** (which deletes `data/`).

### Resuming a previous session

When you launch `opencode` in the TUI, recent sessions are listed on the left-hand sidebar. Select any session to continue the conversation exactly where you left off.

### Browsing sessions from the host (without opening the TUI)

View recent log files to see what happened in past sessions:

```bash
# List all run logs, newest first:
ls -lt data/share/log/

# Tail the most recent log:
tail -f data/share/log/$(ls -t data/share/log/ | head -1)
```

Query the database directly with SQLite (if you have it installed on the host):

```bash
sqlite3 data/share/opencode.db \
  "SELECT id, title, created_at FROM session ORDER BY created_at DESC LIMIT 10;"
```

Or from inside the container (SQLite is available via the opencode binary's bun runtime):

```bash
# Inside the container — list sessions:
ls ~/.local/share/opencode/storage/session/
```

### Wiping session history (without losing auth)

```bash
# On the host — delete only the database, keep auth:
rm data/share/opencode.db data/share/opencode.db-shm data/share/opencode.db-wal
```

OpenCode will create a fresh database on next startup.

---

## Configure Providers

OpenCode detects providers automatically from environment variables set in `.env`.

| Provider | Environment Variable |
|---|---|
| Anthropic (Claude) | `ANTHROPIC_API_KEY` or `opencode auth login` |
| OpenAI (GPT) | `OPENAI_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| Groq | `GROQ_API_KEY` |
| OpenRouter (75+ models) | `OPENROUTER_API_KEY` |
| GitHub Copilot | `GITHUB_TOKEN` |
| Local (Ollama) | `OLLAMA_HOST` or `LOCAL_ENDPOINT` |
| Azure OpenAI | `AZURE_OPENAI_ENDPOINT` + `AZURE_OPENAI_API_KEY` |
| AWS Bedrock | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` |

### Using Local Ollama

The container uses `network_mode: host`, so it can reach Ollama running on your machine directly.

1. Install and run [Ollama](https://ollama.com/) on your host
2. Pull a model: `ollama pull qwen2.5-coder:7b`
3. In `.env`, set: `OLLAMA_HOST=http://localhost:11434`
4. Local models are pre-configured in `data/config/opencode.json`

---

## Configuration Reference

### Directory layout on the host

```
opencode-docker/
├── .env                    ← your API keys and settings (gitignored)
├── .env.example            ← template — copy to .env
├── Dockerfile              ← container image definition
├── docker-compose.yml      ← compose config
├── entrypoint.sh           ← container startup script
├── workspace/              ← YOUR PROJECT FILES (mounted at /workspace)
├── data/
│   ├── config/             ← opencode config (opencode.json, plugins)
│   │   └── opencode.json   ← provider/model configuration
│   └── share/              ← persistent state (auth, db, logs)
│       ├── auth.json       ← OAuth tokens
│       ├── opencode.db     ← session & message history
│       └── log/            ← run logs
└── scripts/
    ├── setup.sh            ← build the Docker image
    ├── run.sh              ← run the container interactively
    ├── clipboard.sh        ← clipboard helpers
    └── cleanup.sh          ← stop / full teardown
```

### Environment variables (`.env`)

```bash
# API Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
GROQ_API_KEY=gsk_...
OPENROUTER_API_KEY=sk-or-...
GITHUB_TOKEN=ghp_...

# Local Ollama (container uses host network, so localhost works)
OLLAMA_HOST=http://localhost:11434

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://myresource.openai.azure.com
AZURE_OPENAI_API_KEY=...
AZURE_OPENAI_API_VERSION=2024-02-15-preview

# AWS Bedrock
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Use a different project directory (default: ./workspace)
WORKSPACE_PATH=./workspace
```

### OpenCode config (`data/config/opencode.json`)

Edit this file to add custom providers or tune model options. It is mounted into the container at `/home/opencode/.config/opencode/opencode.json`. Changes take effect on the next container start — no rebuild needed.

### `run.sh` flags

| Flag | Description |
|---|---|
| `--workspace PATH` | Mount a different directory as `/workspace` |
| `--run` | Launch the OpenCode TUI immediately on startup |
| `--network-host` | Enable host networking (required for Ollama) |
| `--no-clipboard` | Skip X11 clipboard mounting |

---

## Security

### What is isolated

- `~/.ssh`, home directory, and all host files outside `/workspace` are **not accessible** to the agent
- Runs as **non-root user** (UID 1001)
- **no-new-privileges** security option enabled

### What is shared

- **`network_mode: host`** — container can reach localhost services (Ollama, etc.)
- Files in `/workspace` are read-write by the agent
- `./data/` is bind-mounted read-write (persists auth + sessions)

### Fully air-gapped mode (no network access)

```yaml
# In docker-compose.yml, replace network_mode:
network_mode: "none"
```

---

## Tips & Recipes

### Work on a different project

```bash
./scripts/run.sh --workspace ~/my-other-project
```

Sessions are stored per-project in the database, so history for each project is kept separately.

### Start OpenCode directly (skip the shell)

```bash
./scripts/run.sh --run
```

### Using Docker Compose instead of run.sh

```bash
docker compose up -d               # start in background
docker compose exec opencode bash  # open a shell
docker compose down                # stop
```

### Add tools to the container

Edit `Dockerfile` and rebuild:

```dockerfile
RUN apt-get update && apt-get install -y your-tool
```

```bash
./scripts/setup.sh   # rebuilds the image
./scripts/run.sh
```

### Read the logs for a previous session

```bash
# On the host:
ls -lt data/share/log/           # all runs, newest first
cat data/share/log/<timestamp>.log
```

Log lines include the service name, timing, and the opencode version used.

---

## Cleanup

```bash
# Stop the running container (data is preserved):
docker compose down

# Full teardown — removes image, stops containers.
# WARNING: also deletes data/ (auth tokens + all session history):
./scripts/cleanup.sh --full
```

If you want to reset sessions but keep your auth token:

```bash
rm data/share/opencode.db data/share/opencode.db-shm data/share/opencode.db-wal
```

---

## Project Structure

```
opencode-docker/
├── Dockerfile              # Ubuntu 24.04 + opencode-ai npm package
├── entrypoint.sh           # Startup: terminal fix + welcome banner
├── docker-compose.yml      # Two profiles: default (host network) + isolated
├── .env.example            # All supported config variables
├── workspace/              # Your project files (git-tracked separately)
├── data/
│   ├── config/             # opencode.json — provider/model config
│   └── share/              # auth.json, opencode.db, logs (gitignored)
└── scripts/
    ├── setup.sh            # Build image
    ├── run.sh              # Run container (docker run wrapper)
    ├── clipboard.sh        # X11 clipboard helpers
    └── cleanup.sh          # Stop / full teardown
```

---

## Related

- [OpenCode](https://opencode.ai/)
- [OpenCode GitHub](https://github.com/opencode-ai/opencode)
- [Ollama](https://ollama.com/)
