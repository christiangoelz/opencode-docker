# OpenCode Docker - Isolated Development Environment

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange.svg)](https://ubuntu.com/)

Run [OpenCode](https://opencode.ai/) inside a Docker container so it can only touch your project files — not your SSH keys, not your home directory, not your system. Supports 75+ AI providers including Claude, GPT, Gemini, Groq, and local models via Ollama.

---

## Table of Contents

- [Why This Matters](#why-this-matters)
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [Configure Providers](#configure-providers)
- [Clipboard Support](#clipboard-support)
- [Configuration Reference](#configuration-reference)
- [Security](#security)
- [Tips & Recipes](#tips--recipes)
- [Cleanup](#cleanup)

---

## Why This Matters

Running AI coding agents with full permissions on your host system poses risks:
- Accidental access to sensitive files (SSH keys, credentials, personal data)
- Unintended system modifications
- Lack of reproducible development environments

This Docker setup provides:
- **File system isolation** — agent only sees the mounted workspace directory
- **No host file access** — SSH keys, home directory, and system files are protected
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

### Step 3: Authenticate

```bash
# Inside the container - authenticate via OAuth (recommended for subscriptions)
opencode auth login
```

### Step 4: Start coding

```bash
opencode
```

---

## Authentication

### OAuth Login (Recommended for Subscriptions)

OAuth uses your subscription credits (Claude Pro/Max, etc.) instead of API billing:

```bash
# Inside the container:
opencode auth login
```

This will display an authentication URL. Copy it, open in your browser, and complete the login.

### API Keys

For API-based billing, set your keys in `.env`:

```bash
nano .env
# Add your key(s):
# ANTHROPIC_API_KEY=sk-ant-your-key
# OPENAI_API_KEY=sk-your-key
```

Then restart the container:
```bash
./scripts/run.sh
```

---

## Configure Providers

OpenCode handles provider selection through its TUI. Set your API keys as environment variables (in `.env`) and OpenCode will detect them automatically.

| Provider | Environment Variable |
|----------|---------------------|
| Anthropic (Claude) | `ANTHROPIC_API_KEY` or `opencode auth login` |
| OpenAI (GPT) | `OPENAI_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| Groq | `GROQ_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| GitHub Copilot | `GITHUB_TOKEN` |
| Local (Ollama) | `LOCAL_ENDPOINT` or `OLLAMA_PORT` |
| Azure OpenAI | `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY` |
| AWS Bedrock | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |

### Using Local Ollama

1. Install and run [Ollama](https://ollama.com/) on your host machine
2. Pull a model: `ollama pull llama3.2`
3. Start the container: `./scripts/run.sh`
4. Inside: `opencode` and select your local model

---

## Configuration Reference

### Environment Variables (`.env`)

```bash
# API Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
GROQ_API_KEY=gsk_...
OPENROUTER_API_KEY=sk-or-...
GITHUB_TOKEN=ghp_...

# Local Ollama
OLLAMA_PORT=11434
OLLAMA_HOST=localhost
LOCAL_ENDPOINT=http://localhost:11434

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://myresource.openai.azure.com
AZURE_OPENAI_API_KEY=...
AZURE_OPENAI_API_VERSION=2024-02-15-preview

# AWS Bedrock
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Workspace path
WORKSPACE_PATH=./workspace
```

### Script Options (`run.sh`)

| Flag | Description |
|------|-------------|
| `--workspace PATH` | Mount a different directory |
| `--run` | Start OpenCode TUI immediately |

---

## Security

### What is isolated

- `~/.ssh`, home directory, and all host files outside `/workspace` are **not accessible**
- Runs as **non-root user** (UID 1001)
- **no-new-privileges** security option enabled

### What is shared

- **`network_mode: host`** — container can reach localhost services (Ollama, etc.)
- Files in `/workspace` are read-write

### Fully Air-gapped Mode

```yaml
# In docker-compose.yml:
network_mode: "none"
```

---

## Tips & Recipes

### Multiple Projects

```bash
./scripts/run.sh --workspace ~/project-a
./scripts/run.sh --workspace ~/project-b
```

### Using Docker Compose

```bash
docker compose up -d              # Start in background
docker compose exec opencode bash # Enter container
docker compose down               # Stop
```

### Adding Tools

Edit `Dockerfile` and rebuild:
```dockerfile
RUN apt-get update && apt-get install -y your-package
```

```bash
./scripts/setup.sh
```

---

## Cleanup

```bash
# Stop container
docker compose down

# Full cleanup (image + volumes + data)
./scripts/cleanup.sh --full
```

---

## Project Structure

```
opencode-docker/
├── Dockerfile              # Container image
├── entrypoint.sh           # Startup script
├── docker-compose.yml      # Compose config
├── .env.example            # Configuration template
├── workspace/              # Your project files
├── data/                   # Persistent config & logs
│   ├── config/             # OpenCode config
│   └── share/              # OpenCode data & logs
└── scripts/
    ├── setup.sh            # Build image
    ├── run.sh              # Run container
    ├── clipboard.sh        # Clipboard helpers
    └── cleanup.sh          # Cleanup
```

---

## Related

- [OpenCode](https://opencode.ai/)
- [OpenCode GitHub](https://github.com/opencode-ai/opencode)
- [Ollama](https://ollama.com/)
# opencode-docker
