#!/bin/bash
# =============================================================================
# Clipboard helpers for OpenCode Docker
# Provides clipboard access from inside the container.
#
# Methods supported:
#   1. X11 clipboard (xclip/xsel) - requires X11 socket mount and DISPLAY
#   2. File-based clipboard - uses a shared file for clipboard exchange
#   3. OSC 52 terminal escape sequences - works with supported terminals
#
# Commands:
#   clip-copy     Copy stdin to clipboard
#   clip-paste    Paste clipboard contents to stdout
#   clipboard-status  Check which clipboard methods are available
# =============================================================================

# Shared clipboard file location (can be overridden)
CLIPBOARD_FILE="${CLIPBOARD_FILE:-/workspace/.clipboard}"

# ---- Check clipboard availability -------------------------------------------
clipboard-status() {
    echo ""
    echo "Clipboard status:"

    # Check X11
    if [ -n "$DISPLAY" ] && [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] 2>/dev/null; then
        if command -v xclip &> /dev/null; then
            echo "  X11 (xclip):     available (DISPLAY=$DISPLAY)"
        elif command -v xsel &> /dev/null; then
            echo "  X11 (xsel):      available (DISPLAY=$DISPLAY)"
        else
            echo "  X11:             DISPLAY set but no xclip/xsel"
        fi
    else
        echo "  X11:             not available (no DISPLAY or X socket)"
    fi

    # Check file-based clipboard
    if [ -d "$(dirname "$CLIPBOARD_FILE")" ]; then
        echo "  File-based:      available ($CLIPBOARD_FILE)"
    else
        echo "  File-based:      not available"
    fi

    # OSC 52 is always technically available if terminal supports it
    echo "  OSC 52:          depends on terminal (iTerm2, kitty, alacritty, etc.)"
    echo ""
    echo "Usage:"
    echo "  echo 'text' | clip-copy     Copy text to clipboard"
    echo "  clip-paste                  Paste from clipboard"
    echo ""
}

# ---- Copy to clipboard ------------------------------------------------------
clip-copy() {
    local input
    input=$(cat)

    # Try X11 first (most reliable)
    if [ -n "$DISPLAY" ]; then
        if command -v xclip &> /dev/null; then
            echo -n "$input" | xclip -selection clipboard 2>/dev/null && return 0
        elif command -v xsel &> /dev/null; then
            echo -n "$input" | xsel --clipboard --input 2>/dev/null && return 0
        fi
    fi

    # Try OSC 52 escape sequence (works with iTerm2, kitty, etc.)
    if [ -t 1 ]; then
        local encoded
        encoded=$(echo -n "$input" | base64 | tr -d '\n')
        printf '\033]52;c;%s\a' "$encoded"
    fi

    # Always write to file as fallback
    echo -n "$input" > "$CLIPBOARD_FILE" 2>/dev/null

    echo "Copied to clipboard" >&2
}

# ---- Paste from clipboard ---------------------------------------------------
clip-paste() {
    # Try X11 first
    if [ -n "$DISPLAY" ]; then
        if command -v xclip &> /dev/null; then
            xclip -selection clipboard -o 2>/dev/null && return 0
        elif command -v xsel &> /dev/null; then
            xsel --clipboard --output 2>/dev/null && return 0
        fi
    fi

    # Fall back to file-based clipboard
    if [ -f "$CLIPBOARD_FILE" ]; then
        cat "$CLIPBOARD_FILE"
        return 0
    fi

    echo "No clipboard content available" >&2
    return 1
}

# ---- Quick aliases ----------------------------------------------------------
alias pbcopy='clip-copy'
alias pbpaste='clip-paste'
