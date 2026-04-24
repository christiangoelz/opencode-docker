#!/bin/bash
# OpenCode Docker — Entrypoint

# Fix terminal settings for TUI apps (especially with --network host)
if [ -t 0 ] && [ -t 1 ]; then
    # Reset terminal to sane defaults
    stty sane 2>/dev/null || true

    # Ensure TERM is set
    export TERM="${TERM:-xterm-256color}"

    # Update terminal size from actual dimensions
    if command -v resize &>/dev/null; then
        eval "$(resize)" 2>/dev/null || true
    elif [ -n "$LINES" ] && [ -n "$COLUMNS" ]; then
        stty rows "$LINES" cols "$COLUMNS" 2>/dev/null || true
    fi
fi

# Ensure opencode.json exists (copy default if not present, e.g. fresh container)
if [ ! -f "$XDG_CONFIG_HOME/opencode/opencode.json" ]; then
    mkdir -p "$XDG_CONFIG_HOME/opencode"
    cp /home/opencode/defaults/opencode.json "$XDG_CONFIG_HOME/opencode/opencode.json" 2>/dev/null || true
    echo "→ Created default opencode.json with Ollama provider config"
fi

cat <<'WELCOME'
╔════════════════════════════════════════════════════════════════════════════╗
║                          OpenCode Docker                                   ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  First time? Login to your provider:                                       ║
║    opencode auth login                  Authenticate (OAuth)               ║
║                                                                            ║
║  Then start coding:                                                        ║
║    opencode                             Launch the TUI                     ║
║                                                                            ║
║  Or set API keys in .env:                                                  ║
║    ANTHROPIC_API_KEY   OPENAI_API_KEY   GEMINI_API_KEY                     ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
WELCOME

# If arguments are passed, execute them; otherwise start interactive bash
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec /bin/bash
fi
