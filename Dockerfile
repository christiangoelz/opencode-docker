FROM ubuntu:24.04

# Metadata
LABEL maintainer="opencode-docker"
LABEL description="Isolated Docker environment for OpenCode AI"
LABEL version="1.0"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    ripgrep \
    build-essential \
    ca-certificates \
    fzf \
    bsdutils \
    ncurses-base \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 opencode

# Switch to non-root user
USER opencode

# Switch to non-root user
USER opencode
WORKDIR /home/opencode

# Configure npm for non-root global installs
RUN mkdir -p /home/opencode/.npm-global \
    && npm config set prefix '/home/opencode/.npm-global'

# Add npm global bin to PATH and set terminal defaults
ENV PATH="/home/opencode/.npm-global/bin:${PATH}"
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# Pin XDG dirs so opencode always reads/writes to the mounted volumes
# (prevents workspace/.opencode/ from shadowing the persistent data volume)
ENV XDG_DATA_HOME=/home/opencode/.local/share
ENV XDG_CONFIG_HOME=/home/opencode/.config

# Install OpenCode via npm (more reliable than curl install script)
RUN npm install -g opencode-ai@latest

# Create directories for persistent config
RUN mkdir -p /home/opencode/.config/opencode /home/opencode/.local/share/opencode

# Copy default opencode config (Ollama provider pre-configured)
# Stored in /defaults/ so it isn't shadowed by the volume mount
COPY --chown=opencode:opencode data/config/opencode/opencode.json /home/opencode/defaults/opencode.json

# Copy entrypoint script
COPY entrypoint.sh /home/opencode/entrypoint.sh

# Set working directory
WORKDIR /workspace

ENTRYPOINT ["/home/opencode/entrypoint.sh"]
