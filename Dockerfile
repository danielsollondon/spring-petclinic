# ---- Build Stage ----
FROM eclipse-temurin:21.0.10_7-jdk-alpine AS builder

WORKDIR /workspace/app

# Copy Maven wrapper and POM first to leverage layer caching for dependencies
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (cached as a separate layer)
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B --no-transfer-progress

# Copy source and build
COPY src src
RUN ./mvnw package -DskipTests -B --no-transfer-progress

# Extract Spring Boot layered jar for optimized runtime layers (Spring Boot 4.x syntax)
RUN java -Djarmode=tools -jar target/*.jar extract --layers --launcher --destination target/extracted

# Flatten all extracted layers into a single directory so the runtime stage
# needs only one COPY --from=builder. Multiple cross-stage COPYs cause
# "layer does not exist" failures in ACR Tasks.
RUN mkdir -p target/flat && \
    cp -a target/extracted/dependencies/. target/flat/ && \
    cp -a target/extracted/spring-boot-loader/. target/flat/ && \
    cp -a target/extracted/snapshot-dependencies/. target/flat/ && \
    cp -a target/extracted/application/. target/flat/

# ---- Runtime Stage ----
FROM eclipse-temurin:21.0.10_7-jre-alpine AS runtime

# Create a dedicated non-root user with explicit numeric UID/GID (required for runAsNonRoot)
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Single cross-stage COPY to avoid ACR Tasks layer export bug
COPY --from=builder /workspace/app/target/flat/ ./
RUN chown -R 1001:1001 /app

USER appuser

EXPOSE 8080

# Health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
