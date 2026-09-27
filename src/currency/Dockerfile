# Currency service (C++): multi-stage build.
#
# Build from the REPO ROOT, because the build needs pb/demo.proto (outside this folder):
#   docker build -f src/currency/Dockerfile -t currency:v1 .
# Run:
#   docker run --rm currency:v1
#
# Stages:
#   base    -> Alpine + gRPC/Protobuf libraries (needed to build AND to run)
#   builder -> base + compiler tools; builds OpenTelemetry C++, then the currency program
#   release -> base + only the finished program (final image)

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

# ---------- Stage 3: release (final image) ----------
# Fresh copy of base: runtime libraries only, no compiler or source code.
FROM base AS release

# Only the finished program. (Upstream copies all of /usr/local; this keeps the image smaller.)
COPY --from=builder /usr/local/bin/currency /usr/local/bin/currency

# Default port (matches CURRENCY_PORT in .env); override with -e CURRENCY_PORT=...
ENV CURRENCY_PORT=7001
EXPOSE 7001

# Run as Alpine's built-in unprivileged user instead of root.
USER nobody

# The program takes the port as an argument: `currency 7001`.
# sh -c fills in ${CURRENCY_PORT}; exec makes currency the main process so it gets stop signals.
ENTRYPOINT ["sh", "-c", "exec /usr/local/bin/currency ${CURRENCY_PORT}"]
