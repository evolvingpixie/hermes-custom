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
# Add or remove packages below according to your workload needs
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ripgrep \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# 2. Allow passwordless sudo for the unprivileged hermes user (UID 10000) if required
RUN echo 'hermes ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/hermes \
    && chmod 0440 /etc/sudoers.d/hermes

# 3. Copy custom extensions, plugins, skills, and configuration
COPY custom/ /opt/hermes/custom/
RUN chmod -R +rX /opt/hermes/custom && \
    if [ -d /opt/hermes/custom/scripts ]; then \
        chmod +x /opt/hermes/custom/scripts/*.sh 2>/dev/null || true; \
    fi

# 4. Optional: Install additional Python dependencies into Hermes's venv
# If requirements.txt has entries, install them using the container's python/uv
RUN if [ -f /opt/hermes/custom/requirements.txt ] && grep -vqE '^(#|$)' /opt/hermes/custom/requirements.txt; then \
        if [ -x /opt/hermes/.venv/bin/pip ]; then \
            /opt/hermes/.venv/bin/pip install --no-cache-dir -r /opt/hermes/custom/requirements.txt; \
        elif command -v uv >/dev/null 2>&1; then \
            uv pip install --python /opt/hermes/.venv -r /opt/hermes/custom/requirements.txt; \
        fi; \
    fi

# Environment configuration
ENV HERMES_CUSTOM_DIR=/opt/hermes/custom

# Upstream entrypoint & volume contracts are preserved:
# ENTRYPOINT [ "/opt/hermes/docker/entrypoint-dispatch.sh" ]
# VOLUME [ "/opt/data" ]
