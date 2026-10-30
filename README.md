# Custom Hermes Agent Multi-Arch Build

[![Track Upstream Releases](https://github.com/NousResearch/hermes-agent/actions/workflows/docker.yml/badge.svg)](https://github.com/NousResearch/hermes-agent)

This repository contains the container definition and automated CI/CD pipelines to build, customize, and publish a modified multi-architecture container image for [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent).

---

## Features

- **Multi-Architecture Support**: Built for both **`linux/amd64`** (x86_64) and **`linux/arm64`** (AArch64 / Apple Silicon / Raspberry Pi / AWS Graviton).
- **Automated Upstream Tracking**: A GitHub Action periodically checks [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) for new releases. Whenever a new release is tagged upstream, it automatically updates `.upstream-version` and triggers the multi-arch build pipeline.
- **Manual Trigger**: The build workflow can be manually dispatched at any time with custom version parameters (e.g., `latest` or specific tags like `v0.22.5`).
- **Registry Integration**: Publishes out of the box to **GitHub Container Registry (GHCR)** (`ghcr.io/<owner>/<repo>`), with optional support for **Docker Hub**.
- **Extensible Layout**: Built-in support for custom plugins, skills, bash initialization hooks, and additional Python dependencies.

---

## Repository Structure

```text
hermes-custom/
├── .github/
│   └── workflows/
│       ├── build.yml           # Multi-arch (amd64 / arm64) build and publish workflow
│       └── track-upstream.yml  # Automated watcher for upstream NousResearch releases
├── custom/                     # Custom extensions baked into the image
│   ├── plugins/                # Custom agent plugins
│   ├── skills/                 # Custom agent skills
│   ├── scripts/                # Custom initialization and utility scripts
│   │   └── custom-init.sh      # Sample startup script to sync custom skills/plugins
│   ├── requirements.txt        # Extra Python packages to install during build
│   └── README.md
├── .upstream-version           # Tracks the latest known/built upstream release tag
├── Dockerfile                  # Containerfile based on official multi-arch hermes-agent
├── docker-compose.yml          # Local development / deployment setup
├── .dockerignore
└── .gitignore
```

---

## Workflows

### 1. `track-upstream.yml` (Release Watcher)

- **Schedule**: Runs automatically every 6 hours (`cron: '0 */6 * * *'`).
- **Manual Trigger**: Can be dispatched manually from the GitHub Actions tab (`Actions` -> `Track Upstream Releases` -> `Run workflow`). You can toggle `force_build: true` to trigger a build even if no new release was detected.
- **Mechanism**:
  1. Queries the GitHub API for `https://api.github.com/repos/NousResearch/hermes-agent/releases/latest`.
  2. Compares the latest release tag against the version stored in `.upstream-version`.
  3. If a new release is found:
     - Updates `.upstream-version`.
     - Commits and pushes the update back to `main`.
     - Invokes the `build.yml` reusable workflow to build and publish the multi-arch image for the new version.

### 2. `build.yml` (Multi-Arch Builder)

- **Triggers**:
  - **Manual Trigger (`workflow_dispatch`)**:
    - `hermes_version`: Specify an upstream tag (e.g. `v0.22.5`) or `latest`.
    - `push`: Whether to push images to registry (`true`/`false`).
    - `platforms`: Target architectures (defaults to `linux/amd64,linux/arm64`).
  - **Reusable Workflow (`workflow_call`)**: Automatically triggered by `track-upstream.yml`.
  - **Push to `main`**: Automatically triggers when `Dockerfile`, `custom/**`, or `.upstream-version` is updated.
- **Architectures**: Uses Docker Buildx and QEMU to cross-compile and assemble multi-arch manifests for `linux/amd64` and `linux/arm64`.
- **Image Tags**: Automatically tags images with:
  - Upstream version (e.g. `ghcr.io/<owner>/<repo>:v0.22.5` and `0.22.5`)
  - `ghcr.io/<owner>/<repo>:latest`
  - Git commit SHA (e.g. `ghcr.io/<owner>/<repo>:sha-1234567`)

---

## Container Registries

### GitHub Container Registry (GHCR)
Enabled by default. GitHub Actions uses `${{ secrets.GITHUB_TOKEN }}` with package write permissions. No manual token creation is required!

Your images will be published to:
```text
ghcr.io/<your-github-username>/hermes-custom:<tag>
```

### Docker Hub (Optional)
If you want to push to Docker Hub in addition to GHCR, add the following secrets in your GitHub repository settings (`Settings` -> `Secrets and variables` -> `Actions`):
- `DOCKERHUB_USERNAME`: Your Docker Hub username.
- `DOCKERHUB_TOKEN`: Your Docker Hub access token.
- `DOCKERHUB_REPO`: (Optional) Custom repo name on Docker Hub, e.g. `youruser/hermes-custom`.

---

## Customizing the Image

1. **System Packages**: Add or modify packages in `Dockerfile` under the `apt-get install` section.
2. **Python Libraries**: Add library names to `custom/requirements.txt`.
3. **Plugins & Skills**: Place plugins in `custom/plugins/` and skills in `custom/skills/`.
4. **Initialization Hooks**: Modify `custom/scripts/custom-init.sh` to execute custom logic on startup.

---

## Local Development & Testing

### Build Locally
```bash
# Build for your host architecture
docker build -t hermes-agent:custom .

# Or build multi-arch locally with buildx
docker buildx build --platform linux/amd64,linux/arm64 -t hermes-agent:custom .
```

### Run with Docker
```bash
mkdir -p ./data
docker run -it --rm \
  --name hermes-custom \
  -v "$(pwd)/data:/opt/data" \
  hermes-agent:custom
```

### Run with Docker Compose
```bash
docker compose up -d
docker compose logs -f
```
