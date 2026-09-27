# Currency service (C++): multi-stage build.
#
# Build from the REPO ROOT, because the build needs pb/demo.proto (outside this folder):
#   docker build -f src/currency/Dockerfile -t currency:v1 .
# Run:
#   docker run --rm currency:v1
#
# Stages:
#   base    -> Alpine + gRPC/Protobuf -dev packages (needed to build)
#   builder -> base + compiler tools; builds OpenTelemetry C++, then the currency program
#   release -> plain Alpine + only the runtime libraries + the finished program (final image)

# ---------- Stage 1: base ----------
# Pinned Alpine version so library versions don't change between builds.
FROM alpine:3.21 AS base
# gRPC = how services call each other; Protobuf = the message format (see pb/demo.proto).
RUN apk add --no-cache grpc-dev protobuf-dev

# ---------- Stage 2: builder ----------
# Starts from base (already has gRPC/Protobuf). Nothing added here reaches the final image
# except what release copies with COPY --from=builder.
FROM base AS builder

# Build tools: git (download), cmake + make (build system), g++ (C++ compiler), linux-headers.
RUN apk add --no-cache git cmake make g++ linux-headers

# OpenTelemetry C++ library, pinned (same version as OPENTELEMETRY_CPP_VERSION in .env).
# Alpine has no package for it, so it's compiled from source. This is the slow step (30-60 min).
# Output: libraries + headers in /usr/local (building blocks, not a program).
ARG OPENTELEMETRY_CPP_VERSION=1.21.0
RUN git clone --depth 1 --branch v${OPENTELEMETRY_CPP_VERSION} https://github.com/open-telemetry/opentelemetry-cpp \
    && cd opentelemetry-cpp && mkdir build && cd build \
    && cmake .. -DCMAKE_CXX_STANDARD=17 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
       -DWITH_EXAMPLES=OFF -DWITH_OTLP_GRPC=ON -DWITH_ABSEIL=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    && make -j$(nproc) install

WORKDIR /currency

# Service source. Paths start with src/currency/ because the build context is the repo root.
COPY src/currency/src/ src/
COPY src/currency/proto/ proto/
COPY src/currency/build/ build/

# Build recipes: genproto turns demo.proto into C++ code; the main one builds the program.
COPY src/currency/genproto/CMakeLists.txt genproto/CMakeLists.txt
COPY src/currency/CMakeLists.txt CMakeLists.txt

# Shared API definition used by every service (lives at the repo root).
COPY pb/demo.proto proto/demo.proto

# Compile: generate code from demo.proto, compile server.cpp, link with gRPC/Protobuf/OpenTelemetry.
# Result: the executable /usr/local/bin/currency.
RUN mkdir -p build && cd build \
    && cmake .. \
    && make -j$(nproc) install

# List the system libraries the program actually needs at runtime.
# scanelf reads the "needed libraries" from the binary and our .so files; libraries we
# copy ourselves (/usr/local/lib) are skipped; the rest become apk names like "so:libgrpc++.so.1.x".
RUN apk add --no-cache scanelf \
    && scanelf --needed --nobanner --format '%n#p' /usr/local/bin/currency /usr/local/lib/*.so* \
       | tr ',' '\n' | sort -u \
       | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
       > /runtime-deps.txt

# ---------- Stage 3: release (final image) ----------
# Plain Alpine (NOT base): base has the -dev packages (headers, protoc, static libs) that are
# only needed to build. Here we install only the runtime libraries listed above.
FROM alpine:3.21 AS release

# Links the image to the GitHub repo when pushed to ghcr.io (no manual "Connect Repository").
LABEL org.opencontainers.image.source="https://github.com/icbannerman/astronomy-ecommerce-shop-project" \
      org.opencontainers.image.title="currency" \
      org.opencontainers.image.description="Currency conversion gRPC service (C++) for the Astronomy Shop"

COPY --from=builder /runtime-deps.txt /tmp/runtime-deps.txt
RUN apk add --no-cache $(cat /tmp/runtime-deps.txt) && rm /tmp/runtime-deps.txt

# The finished program, plus the shared OpenTelemetry libraries (.so) it loads at startup.
# (Without the .so files it fails with "Error relocating ... symbol not found".)
# Upstream copies all of /usr/local; copying only these keeps the image smaller.
COPY --from=builder /usr/local/bin/currency /usr/local/bin/currency
COPY --from=builder /usr/local/lib/*.so* /usr/local/lib/

# Default port (matches CURRENCY_PORT in .env); override with -e CURRENCY_PORT=...
ENV CURRENCY_PORT=7001
# server.cpp reads VERSION with getenv() and crashes if it's unset
# ("basic_string: construction from null"). docker-compose sets it; this is the fallback.
ENV VERSION=2.1.3
EXPOSE 7001

# Run as Alpine's built-in unprivileged user instead of root.
USER nobody

# The program takes the port as an argument: `currency 7001`.
# sh -c fills in ${CURRENCY_PORT}; exec makes currency the main process so it gets stop signals.
ENTRYPOINT ["sh", "-c", "exec /usr/local/bin/currency ${CURRENCY_PORT}"]
