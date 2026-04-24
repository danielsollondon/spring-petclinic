# syntax=docker/dockerfile:1
# ──────────────────────────────────────────────────────────────────────────────
# Stage 1 – Build
# ──────────────────────────────────────────────────────────────────────────────
FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /workspace

# Copy wrapper + POM first so Maven dependency layer is cached independently
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Pre-fetch all dependencies (cached unless pom.xml changes)
# BuildKit cache mount keeps the Maven local repo between builds (faster rebuilds)
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    chmod +x mvnw && ./mvnw -q -DskipTests dependency:go-offline

# Copy source and build the fat JAR
COPY src src
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    ./mvnw -q -DskipTests package

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2 – Runtime
# ──────────────────────────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-jammy

LABEL org.opencontainers.image.source="https://github.com/danielsollondon/spring-petclinic" \
      org.opencontainers.image.title="spring-petclinic" \
      org.opencontainers.image.description="Spring PetClinic sample application"

ENV JAVA_OPTS=""

WORKDIR /app

# Install curl (needed for HEALTHCHECK) and create a non-root system user
# (UID 10001, primary group root for OpenShift compatibility)
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 10001 -g root appuser

# Copy the fat JAR and set ownership in one layer
COPY --from=build --chown=10001:0 /workspace/target/*.jar /app/app.jar

USER 10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Use exec form via shell to honour $JAVA_OPTS at runtime
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]