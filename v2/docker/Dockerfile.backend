FROM eclipse-temurin:21-jre

WORKDIR /app

# 🔹 OpenTelemetry Java Agent 다운로드
RUN curl -L -o opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.3.0/opentelemetry-javaagent.jar

COPY build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-Dotel.service.name=backend-service", "-Dotel.exporter.otlp.endpoint=http://35.216.67.116:4317", "-Dotel.exporter.otlp.protocol=grpc", "-Dotel.resource.attributes=deployment.environment=dev", "-Dotel.instrumentation.jvm-metrics.enabled=true",  "-jar", "app.jar"]