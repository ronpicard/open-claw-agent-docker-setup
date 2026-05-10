# Ubuntu dev image for OpenClaw (https://github.com/openclaw/openclaw)
# Requires Node >= 22 (OpenClaw npm package: >= 22.14). In Docker, run the gateway in the foreground instead of systemd.
FROM ubuntu:24.04

# Silence every interactive prompt during build:
#   DEBIAN_FRONTEND=noninteractive  -> apt / dpkg never prompt for tz, restarts, conffiles
#   NEEDRESTART_MODE=a              -> needrestart auto-restarts services (no menu)
#   CI=1                            -> most third-party install scripts treat this as "yes to all"
#   COREPACK_ENABLE_DOWNLOAD_PROMPT -> corepack downloads pnpm without the Y/n confirm
ARG DEBIAN_FRONTEND=noninteractive
ARG NEEDRESTART_MODE=a
ARG CI=1
ARG COREPACK_ENABLE_DOWNLOAD_PROMPT=0

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
# Add the NodeSource apt repo manually instead of `curl ... | bash` so the
# install is fully deterministic and can never prompt or print interactive
# warnings (the upstream setup_22.x script can pause on EOL/deprecation notices).
RUN install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@latest --activate </dev/null

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
RUN npm install -g --no-fund --no-audit openclaw@latest </dev/null

# Claude Code CLI — https://docs.anthropic.com/en/docs/claude-code/setup (native installer; binary -> ~/.local/bin/claude)
# Do not use `curl ... | bash </dev/null`: the redirect attaches to the piped `bash`, so its stdin is
# /dev/null instead of the curl pipe (curl then fails with "Failure writing output to destination" and
# nothing installs). Run the pipeline under `bash -c` so only the outer shell has stdin closed.
RUN bash -c 'curl -fsSL https://claude.ai/install.sh | bash' </dev/null

# Fail the image build if either CLI did not land on PATH
RUN command -v openclaw >/dev/null && command -v claude >/dev/null \
  && claude --version \
  && openclaw --version
