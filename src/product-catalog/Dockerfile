# syntax=docker/dockerfile:1
#
# Product Catalog service (Go): multi-stage build.
#   Stage 1 (builder): compile a static Go binary.
#   Stage 2 (release): copy only the binary + product data into a minimal, non-root image.
#
# Build (from this folder):  docker build -t product-catalog:v1 .
# Run:                       docker run --rm product-catalog:v1

# ---------- Stage 1: build ----------
# Pinned to the Go version required by go.mod (go 1.24.x).
FROM golang:1.24-alpine AS builder

WORKDIR /usr/src/app

# Copy only the dependency manifests first, so this layer (and the slow
# download below) is cached until go.mod/go.sum change.
COPY go.mod go.sum ./

# Cache mount keeps downloaded modules between builds (BuildKit).
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy only the source the build needs, not the whole folder.
COPY main.go ./
COPY genproto/ ./genproto/

# CGO_ENABLED=0 -> fully static binary (no C libraries needed at runtime).
# -ldflags "-s -w" -> strip debug symbols for a smaller binary.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o product-catalog .

# ---------- Stage 2: release ----------
# Distroless "static": no shell, no package manager, only what a static binary needs.
# ":nonroot" runs as UID 65532 instead of root.
FROM gcr.io/distroless/static-debian12:nonroot AS release

LABEL org.opencontainers.image.title="product-catalog" \
      org.opencontainers.image.description="Product Catalog gRPC service for the Astronomy Shop" \
      org.opencontainers.image.source="https://github.com/icbannerman/astronomy-ecommerce-shop-project"

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app/product-catalog ./
# The service reads ./products/*.json at startup.
COPY products/ ./products/

# Default port; override at runtime with -e PRODUCT_CATALOG_PORT=...
ENV PRODUCT_CATALOG_PORT=3550
EXPOSE 3550

USER nonroot:nonroot

ENTRYPOINT ["./product-catalog"]
