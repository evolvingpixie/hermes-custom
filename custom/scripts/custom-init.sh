#!/usr/bin/env bash
set -e

# Custom initialization hook for Hermes Agent container.
# This script runs during container setup or when invoked by entrypoint.
# It handles volume reconciliation, skills/plugins sync, and arch-safe binary healing.

echo "[custom-init] Running custom initialization..."

DATA_DIR="${HERMES_HOME:-/opt/data}"
CUSTOM_DIR="/opt/hermes/custom"

# 1. Sync custom skills if present
if [ -d "${CUSTOM_DIR}/skills" ] && [ -n "$(ls -A "${CUSTOM_DIR}/skills" 2>/dev/null)" ]; then
    echo "[custom-init] Syncing custom skills to ${DATA_DIR}/skills..."
    mkdir -p "${DATA_DIR}/skills"
    cp -rn "${CUSTOM_DIR}/skills/"* "${DATA_DIR}/skills/" 2>/dev/null || true
    chown -R hermes:hermes "${DATA_DIR}/skills" 2>/dev/null || true
fi

# 2. Sync custom plugins if present
if [ -d "${CUSTOM_DIR}/plugins" ] && [ -n "$(ls -A "${CUSTOM_DIR}/plugins" 2>/dev/null)" ]; then
    echo "[custom-init] Syncing custom plugins to ${DATA_DIR}/plugins..."
    mkdir -p "${DATA_DIR}/plugins"
    cp -rn "${CUSTOM_DIR}/plugins/"* "${DATA_DIR}/plugins/" 2>/dev/null || true
    chown -R hermes:hermes "${DATA_DIR}/plugins" 2>/dev/null || true
fi

# 3. Heal any architecture-mismatched tirith binary in volume bin/
if [ -d "${DATA_DIR}/bin" ]; then
    if [ -f "${DATA_DIR}/bin/tirith" ]; then
        if ! "${DATA_DIR}/bin/tirith" --version >/dev/null 2>&1; then
            echo "[custom-init] Detected broken/mismatched ${DATA_DIR}/bin/tirith. Replacing with native /usr/local/bin/tirith..."
            ln -sf /usr/local/bin/tirith "${DATA_DIR}/bin/tirith"
        fi
    else
        ln -sf /usr/local/bin/tirith "${DATA_DIR}/bin/tirith" 2>/dev/null || true
    fi
fi

echo "[custom-init] Initialization complete."
