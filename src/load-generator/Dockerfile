# syntax=docker/dockerfile:1
#
# Load Generator (Python / Locust + Playwright): multi-stage build.
#
# Build from THIS folder (everything it needs is inside src/load-generator/):
#   cd src/load-generator
#   docker build --provenance=false -t ghcr.io/icbannerman/load-generator:v1 .
#
# Stages:
#   builder -> Python + g++; installs the libraries from requirements.txt into a venv
#   release -> Python (no compiler) + the venv + Chromium + the Locust script (final image)

# ---------- Stage 1: builder ----------
# Python 3.12 on slim Debian 12 (bookworm), pinned so it doesn't change between builds.
FROM python:3.12-slim-bookworm AS builder

# g++ compiles the C parts of some Python libraries during pip install.
# --no-install-recommends skips optional extras; removing the apt lists saves space.
RUN apt-get update && apt-get install -y --no-install-recommends g++ && rm -rf /var/lib/apt/lists/*

# Virtual environment: one self-contained folder with all the libraries, easy to copy later.
RUN python -m venv /opt/venv
# Put the venv first on PATH, so pip/python below use (and install into) the venv.
ENV PATH="/opt/venv/bin:$PATH"

# Library list first, so the slow install below is cached until requirements.txt changes.
COPY requirements.txt .
# Cache mount keeps downloaded packages between builds (BuildKit).
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

# ---------- Stage 2: release (final image) ----------
# Same Python image as the builder (must match, or the venv breaks), but without g++.
FROM python:3.12-slim-bookworm AS release

# Links the image to the GitHub repo when pushed to ghcr.io.
LABEL org.opencontainers.image.source="https://github.com/icbannerman/astronomy-ecommerce-shop-project" \
      org.opencontainers.image.title="load-generator" \
      org.opencontainers.image.description="Locust load generator (Python + Playwright) for the Astronomy Shop"

# Only the installed libraries from the builder.
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers

# Chromium + the system libraries it needs, for simulated browser traffic. The biggest layer.
# --with-deps runs apt-get; removing the apt lists afterwards keeps the layer smaller.
RUN playwright install --with-deps chromium && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
# The Locust script and the fake customer data it uses.
COPY locustfile.py people.json ./

# Run as an unprivileged user instead of root.
RUN useradd --system --uid 10001 app
USER app

# Locust's web UI (served at /loadgen through the frontend proxy).
EXPOSE 8089

# Starts Locust, which runs locustfile.py from the current folder.
ENTRYPOINT ["locust", "--skip-log-setup"]
