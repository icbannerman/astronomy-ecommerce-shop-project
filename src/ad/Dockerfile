# syntax=docker/dockerfile:1
#
# Ad service (Java 21): multi-stage build.
#
# Build from the REPO ROOT, because the build needs pb/demo.proto (outside this folder):
#   docker build --provenance=false -f src/ad/Dockerfile -t ghcr.io/icbannerman/ad:v1 .
# Run:
#   docker run --rm ghcr.io/icbannerman/ad:v1
#
# Stages:
#   builder -> JDK 21 + Gradle wrapper; `installDist` produces a start script + lib/ of jars
#   release -> JRE 21 + OpenTelemetry Java agent + the installed app (final image)

# ---------- Stage 1: builder ----------
# JDK 21 = compiler + tools. Matches sourceCompatibility = VERSION_21 in build.gradle.
FROM eclipse-temurin:21-jdk AS builder

WORKDIR /usr/src/app

# Only what the build needs: the Gradle wrapper (downloads the Gradle version pinned in
# gradle/wrapper/gradle-wrapper.properties), the build files, and the source code.
COPY src/ad/gradlew src/ad/settings.gradle src/ad/build.gradle ./
COPY src/ad/gradle/ gradle/
COPY src/ad/src/ src/

# Shared API definition from the repo root. build.gradle reads it from -PprotoSourceDir.
COPY pb/ proto/

# Download Gradle + libraries, generate code from demo.proto, compile, and "install" the app:
# build/install/opentelemetry-demo-ad/ with bin/Ad (start script) and lib/ (all jars).
# Cache mount keeps Gradle and downloaded libraries between builds.
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew installDist -PprotoSourceDir=./proto --no-daemon

# ---------- Stage 2: release (final image) ----------
# JRE 21 = just the JVM. Not distroless: bin/Ad is a shell script, so the image needs a shell.
FROM eclipse-temurin:21-jre AS release

# Links the image to the GitHub repo when pushed to ghcr.io.
LABEL org.opencontainers.image.source="https://github.com/icbannerman/astronomy-ecommerce-shop-project" \
      org.opencontainers.image.title="ad" \
      org.opencontainers.image.description="Ad gRPC service (Java) for the Astronomy Shop"

WORKDIR /usr/src/app

# OpenTelemetry Java agent: traces the app automatically, no code changes.
# Pinned to the same version as OTEL_JAVA_AGENT_VERSION in .env.
ARG OTEL_JAVA_AGENT_VERSION=2.20.1
ADD --chmod=644 https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar \
    opentelemetry-javaagent.jar

# Only the installed app (bin/ + lib/), not the source code or Gradle.
COPY --from=builder /usr/src/app/build/install/opentelemetry-demo-ad/ ./

# AD_PORT is required: AdService throws "AD_PORT must not be null" without it.
# Default matches .env; docker-compose overrides it.
ENV AD_PORT=9555
# -javaagent: load the OpenTelemetry agent. MaxRAMPercentage: size the heap from the container limit.
ENV JAVA_TOOL_OPTIONS="-javaagent:/usr/src/app/opentelemetry-javaagent.jar -XX:MaxRAMPercentage=75"
EXPOSE 9555

# Run as an unprivileged user instead of root.
RUN useradd --system --uid 10001 app
USER app

ENTRYPOINT ["./bin/Ad"]
