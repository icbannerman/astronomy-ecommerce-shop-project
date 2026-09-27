# syntax=docker/dockerfile:1
#
# Fraud Detection service (Kotlin on the JVM): multi-stage build.
#
# Build from the REPO ROOT, because the build needs pb/demo.proto (outside this folder):
#   docker build --provenance=false \
#     --annotation "org.opencontainers.image.source=https://github.com/icbannerman/astronomy-ecommerce-shop-project" \
#     -f src/fraud-detection/Dockerfile -t ghcr.io/icbannerman/fraud-detection:v1 .
#
# It has no port: it reads order events from Kafka. KAFKA_ADDR is required (the app exits
# without it); docker-compose.yml provides it.
#
# Stages:
#   builder -> JDK + Gradle wrapper; compiles the Kotlin code into one "fat jar"
#   release -> distroless Java 17 runtime + OpenTelemetry Java agent + the jar (final image)

# ---------- Stage 1: builder ----------
# JDK 17 = compiler + tools. Version matches jvmTarget = JVM_17 in build.gradle.kts.
FROM eclipse-temurin:17-jdk AS builder

WORKDIR /usr/src/app

# Only what the build needs: the Gradle wrapper (downloads the Gradle version pinned in
# gradle/wrapper/gradle-wrapper.properties), the build files, and the source code.
COPY src/fraud-detection/gradlew src/fraud-detection/settings.gradle.kts \
     src/fraud-detection/build.gradle.kts src/fraud-detection/gradle.properties ./
COPY src/fraud-detection/gradle/ gradle/
COPY src/fraud-detection/src/ src/

# Shared API definition from the repo root, placed where the Gradle Protobuf plugin looks for it.
COPY pb/ src/main/proto/

# Download Gradle + libraries, generate code from demo.proto, compile, and package everything
# into one fat jar: build/libs/fraud-detection-1.0-all.jar
# Cache mount keeps Gradle and downloaded libraries between builds (much faster rebuilds).
# --no-daemon: don't leave a background Gradle process running (pointless in a one-off build).
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew shadowJar --no-daemon

# ---------- Stage 2: release (final image) ----------
# Distroless Java 17: just the JVM, no shell or package manager. ":nonroot" = runs as UID 65532.
FROM gcr.io/distroless/java17-debian12:nonroot AS release

# Links the image to the GitHub repo when pushed to ghcr.io.
LABEL org.opencontainers.image.source="https://github.com/icbannerman/astronomy-ecommerce-shop-project" \
      org.opencontainers.image.title="fraud-detection" \
      org.opencontainers.image.description="Fraud detection Kafka consumer (Kotlin) for the Astronomy Shop"

WORKDIR /usr/src/app

# OpenTelemetry Java agent: traces the app automatically, no code changes.
# Pinned to the same version as OTEL_JAVA_AGENT_VERSION in .env.
ARG OTEL_JAVA_AGENT_VERSION=2.20.1
ADD --chmod=644 https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar \
    opentelemetry-javaagent.jar

# Only the fat jar (app + all its libraries in one file).
COPY --from=builder /usr/src/app/build/libs/fraud-detection-1.0-all.jar app.jar

# -javaagent: load the OpenTelemetry agent at startup.
# MaxRAMPercentage: size the JVM heap from the container's memory limit, not the host's.
ENV JAVA_TOOL_OPTIONS="-javaagent:/usr/src/app/opentelemetry-javaagent.jar -XX:MaxRAMPercentage=75"

ENTRYPOINT ["java", "-jar", "app.jar"]
