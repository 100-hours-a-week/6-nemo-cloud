# 빌드 스테이지
FROM gradle:8.5-jdk21 AS builder

ARG SENTRY_AUTH_TOKEN

WORKDIR /app

COPY settings.gradle.kts build.gradle.kts gradle/ ./
RUN gradle dependencies --no-daemon

COPY src ./src
RUN gradle build --no-daemon

# 런타임 스테이지
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
