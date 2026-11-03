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
ARG TARGETARCH

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
# - libopus0 / libopus-dev: Discord voice channel playback
# - libportaudio2: Python sounddevice / audio tools
# - tesseract-ocr / tesseract-ocr-eng: OCR backend for ocrmypdf
# - file: MIME & ELF inspection
# - bind9-dnsutils / iproute2 / netcat-openbsd: Network diagnostics in cluster environments
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    jq yq \
    ripgrep \
    procps \
    sudo \
    vim \
    file \
    golang \
    python3-pip \
    libopus0 libopus-dev \
    libportaudio2 libportaudiocpp0 \
    tesseract-ocr tesseract-ocr-eng \
    bind9-dnsutils iproute2 netcat-openbsd \
    cargo rustc \
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
    fi && \
    if [ -d /opt/hermes/custom/bin ]; then \
        chmod +x /opt/hermes/custom/bin/* 2>/dev/null || true; \
    fi

# 5. Wire custom initialization hook into s6-overlay cont-init.d (runs after 01-hermes-setup)
RUN if [ -f /opt/hermes/custom/scripts/custom-init.sh ]; then \
        mkdir -p /etc/cont-init.d && \
        printf '#!/command/with-contenv sh\nexec /opt/hermes/custom/scripts/custom-init.sh\n' > /etc/cont-init.d/016-custom-setup && \
        chmod +x /etc/cont-init.d/016-custom-setup; \
    fi

# 6. Install additional Python dependencies into Hermes's virtual environment
RUN if [ -f /opt/hermes/custom/requirements.txt ] && grep -vqE '^(#|$)' /opt/hermes/custom/requirements.txt; then \
        uv pip install --python /opt/hermes/.venv -r /opt/hermes/custom/requirements.txt && \
        chmod -R a+rX /opt/hermes/.venv; \
    fi

# 6b. Install custom CLI utilities from custom/bin onto the global PATH
# - gale-news: Gale Cengage newspaper search/list/download CLI (Python 3, requests + bs4)
RUN if [ -d /opt/hermes/custom/bin ]; then \
        for f in /opt/hermes/custom/bin/*; do \
            [ -f "$f" ] || continue; \
            ln -sf "$f" "/usr/local/bin/$(basename "$f")"; \
        done; \
    fi && \
    command -v gale-news >/dev/null && \
    gale-news --help >/dev/null

# Environment configuration
ENV HERMES_CUSTOM_DIR=/opt/hermes/custom

# 7. Install Tirith terminal security guardrail CLI (multi-arch for amd64 / arm64)
ARG TIRITH_VERSION=0.4.2
RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
        amd64) tirith_arch="x86_64" ;; \
        arm64) tirith_arch="aarch64" ;; \
        *) tirith_arch="x86_64" ;; \
    esac; \
    curl -fsSL -o /tmp/tirith.tar.gz "https://github.com/sheeki03/tirith/releases/download/v${TIRITH_VERSION}/tirith-${tirith_arch}-unknown-linux-gnu.tar.gz"; \
    tar -xzf /tmp/tirith.tar.gz -C /usr/local/bin/ tirith tirith-package-approval-authority; \
    chmod 755 /usr/local/bin/tirith /usr/local/bin/tirith-package-approval-authority; \
    rm -f /tmp/tirith.tar.gz; \
    /usr/local/bin/tirith --version

# 8. Install Go CLI utilities (blogwatcher-cli) into /usr/local/bin
RUN GOBIN=/usr/local/bin go install github.com/JulienTant/blogwatcher-cli/cmd/blogwatcher-cli@latest

# 9. Install Antigravity CLI and expose globally
USER hermes
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
USER root
RUN if [ -f /opt/data/.local/bin/agy ]; then \
        cp /opt/data/.local/bin/agy /usr/local/bin/agy && \
        chmod 755 /usr/local/bin/agy; \
    fi

# 10. Install Bitwarden CLI (multi-arch for amd64 / arm64)
ARG BITWARDEN_CLI_VERSION=2026.10.1
RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
        amd64) bw_asset="bw-linux-${BITWARDEN_CLI_VERSION}.zip" ;; \
        arm64) bw_asset="bw-linux-arm64-${BITWARDEN_CLI_VERSION}.zip" ;; \
        *) bw_asset="bw-linux-${BITWARDEN_CLI_VERSION}.zip" ;; \
    esac; \
    curl -fsSL -o /tmp/bw.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BITWARDEN_CLI_VERSION}/${bw_asset}"; \
    unzip -o -q /tmp/bw.zip -d /usr/local/bin/ && \
    chmod 755 /usr/local/bin/bw && \
    rm -f /tmp/bw.zip; \
    /usr/local/bin/bw --version

USER root
# Upstream entrypoint & volume contracts are preserved:
# ENTRYPOINT [ "/opt/hermes/docker/entrypoint-dispatch.sh" ]
# VOLUME [ "/opt/data" ]
