#syntax=docker/dockerfile:1
# ------------------------------------------------------------------------------
# Modified Hermes Agent Container Image
# Upstream: https://github.com/NousResearch/hermes-agent
# Multi-arch: Supports linux/amd64 and linux/arm64
# ------------------------------------------------------------------------------

ARG HERMES_VERSION=latest
FROM nousresearch/hermes-agent:${HERMES_VERSION}

# Metadata Arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${HERMES_VERSION}

# OCI Annotations
LABEL org.opencontainers.image.title="Hermes Agent (Modified)" \
      org.opencontainers.image.description="Custom multi-architecture build of Nous Research Hermes Agent" \
      org.opencontainers.image.url="https://github.com/NousResearch/hermes-agent" \
      org.opencontainers.image.source="https://github.com/NousResearch/hermes-agent" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT"

USER root

# 1. Install additional system packages and CLI utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq yq \
    ripgrep \
    procps \
    sudo \
    vim \
    golang \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 2. Allow passwordless sudo for the unprivileged hermes user (UID 10000)
RUN echo 'hermes ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/hermes \
    && chmod 0440 /etc/sudoers.d/hermes

# 3. Install uv globally to /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    cp /root/.local/bin/uv* /usr/local/bin/ && \
    chmod 755 /usr/local/bin/uv*

# 4. Copy custom extensions, plugins, skills, and configuration
COPY custom/ /opt/hermes/custom/
RUN chmod -R +rX /opt/hermes/custom && \
    if [ -d /opt/hermes/custom/scripts ]; then \
        chmod +x /opt/hermes/custom/scripts/*.sh 2>/dev/null || true; \
    fi

# 5. Install additional Python dependencies into Hermes's virtual environment
RUN if [ -f /opt/hermes/custom/requirements.txt ] && grep -vqE '^(#|$)' /opt/hermes/custom/requirements.txt; then \
        uv pip install --python /opt/hermes/.venv -r /opt/hermes/custom/requirements.txt && \
        chmod -R a+rX /opt/hermes/.venv; \
    fi

# Environment configuration
ENV HERMES_CUSTOM_DIR=/opt/hermes/custom

# 6. Install Go CLI utilities (blogwatcher-cli) into /usr/local/bin
RUN GOBIN=/usr/local/bin go install github.com/JulienTant/blogwatcher-cli/cmd/blogwatcher-cli@latest

# 7. Install Antigravity CLI and expose globally
USER hermes
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
USER root
RUN if [ -f /opt/data/.local/bin/agy ]; then \
        cp /opt/data/.local/bin/agy /usr/local/bin/agy && \
        chmod 755 /usr/local/bin/agy; \
    fi

USER root
# Upstream entrypoint & volume contracts are preserved:
# ENTRYPOINT [ "/opt/hermes/docker/entrypoint-dispatch.sh" ]
# VOLUME [ "/opt/data" ]
