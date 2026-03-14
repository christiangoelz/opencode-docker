#!/bin/bash
# Wrapper to launch opencode with proper terminal settings
# Use this if you experience TUI issues with --network host

# Reset terminal
stty sane 2>/dev/null || true

# Get actual terminal size and set it
if [ -t 0 ]; then
    # Try to get size from terminal
    size=$(stty size 2>/dev/null)
    if [ -n "$size" ]; then
        rows=$(echo "$size" | cut -d' ' -f1)
        cols=$(echo "$size" | cut -d' ' -f2)
        export LINES="$rows"
        export COLUMNS="$cols"
    fi
fi

# Ensure TERM is set correctly
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

# Run opencode
exec opencode "$@"
