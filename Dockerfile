# ---- Build Stage ----
FROM eclipse-temurin:21-jdk-alpine AS builder

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

# ---- Runtime Stage ----
FROM eclipse-temurin:21-jre-alpine AS runtime

# Create a dedicated non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy layered contents (ordered least-to-most volatile for optimal layer caching)
COPY --from=builder --chown=appuser:appgroup /workspace/app/target/extracted/dependencies/ ./
COPY --from=builder --chown=appuser:appgroup /workspace/app/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appgroup /workspace/app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appgroup /workspace/app/target/extracted/application/ ./

USER appuser

EXPOSE 8080

# Health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
