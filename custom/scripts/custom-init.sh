#!/usr/bin/env bash
set -e

# Custom initialization hook for Hermes Agent container.
# This script runs during container setup or when invoked by entrypoint.
# It can sync baked custom plugins/skills into the persistent /opt/data volume.

echo "[custom-init] Running custom initialization..."

DATA_DIR="${HERMES_HOME:-/opt/data}"
CUSTOM_DIR="/opt/hermes/custom"

# Ensure skills directory exists and sync custom skills if present
if [ -d "${CUSTOM_DIR}/skills" ] && [ "$(ls -A "${CUSTOM_DIR}/skills" 2>/dev/null)" ]; then
    echo "[custom-init] Syncing custom skills to ${DATA_DIR}/skills..."
    mkdir -p "${DATA_DIR}/skills"
    cp -rn "${CUSTOM_DIR}/skills/"* "${DATA_DIR}/skills/" 2>/dev/null || true
fi

# Ensure plugins directory exists and sync custom plugins if present
if [ -d "${CUSTOM_DIR}/plugins" ] && [ "$(ls -A "${CUSTOM_DIR}/plugins" 2>/dev/null)" ]; then
    echo "[custom-init] Syncing custom plugins to ${DATA_DIR}/plugins..."
    mkdir -p "${DATA_DIR}/plugins"
    cp -rn "${CUSTOM_DIR}/plugins/"* "${DATA_DIR}/plugins/" 2>/dev/null || true
fi

echo "[custom-init] Initialization complete."
