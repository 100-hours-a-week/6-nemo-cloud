# 1. Gradle 빌드용 베이스 이미지
FROM gradle:8.5-jdk21 AS builder

# 2. 빌드 시 사용될 ARG
ARG SENTRY_AUTH_TOKEN
ENV SENTRY_AUTH_TOKEN=${SENTRY_AUTH_TOKEN}

# 3. 소스 복사 및 빌드
WORKDIR /app
COPY . .
RUN gradle build -x test

# 4. 실행용 경량 이미지
FROM eclipse-temurin:21-jre

# 5. 실행 시에도 환경변수 유지하려면 다시 지정
ARG SENTRY_AUTH_TOKEN
ENV SENTRY_AUTH_TOKEN=${SENTRY_AUTH_TOKEN}

WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
