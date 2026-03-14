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
