# Ubuntu dev image for OpenClaw (https://github.com/openclaw/openclaw)
# Requires Node >= 22 (OpenClaw npm package: >= 22.14). In Docker, run the gateway in the foreground instead of systemd.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# ubuntu:24.04 ships with user/group ubuntu (uid/gid 1000) — reuse for volume permissions
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    lsof \
    openssh-client \
    procps \
    python3 \
    sudo \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# passwordless sudo for container dev workflows
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu

# Node.js 22 LTS (OpenClaw README: Node >= 22)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /workspace
RUN chown ubuntu:ubuntu /workspace

USER ubuntu

# Global npm installs without root
ENV NPM_CONFIG_PREFIX=/home/ubuntu/.local
ENV PATH="/home/ubuntu/.local/bin:${PATH}"

# OpenClaw CLI — https://github.com/openclaw/openclaw (requires Node >= 22.14 per package engines)
# After start: `openclaw onboard` for providers/API keys.
# Gateway: this image has no systemd — run the WebSocket server in the foreground:
#   openclaw gateway run [--port 18789] [--verbose]
# Do not use `openclaw gateway restart` / `gateway install` here; those expect a user systemd unit.
RUN npm install -g openclaw@latest

# Claude Code CLI — https://docs.anthropic.com/en/docs/claude-code/setup (native installer; binary -> ~/.local/bin/claude)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Fail the image build if either CLI did not land on PATH
RUN command -v openclaw >/dev/null && command -v claude >/dev/null \
  && claude --version \
  && openclaw --version
