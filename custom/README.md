# Custom Extensions Directory

This folder holds customizations baked into the Docker image:

- `plugins/`: Place custom Hermes Agent plugins here.
- `skills/`: Place custom agent skills here.
- `scripts/`: Custom bash / initialization scripts (e.g., `custom-init.sh`).
- `requirements.txt`: Extra Python libraries to install during the Docker build.

Files in this directory are copied to `/opt/hermes/custom/` in the container.
