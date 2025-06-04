# 빌드 스테이지
FROM node:22 AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@10.10.0 --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

# 런타임 스테이지
FROM node:22-slim AS runner

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@10.10.0 --activate

COPY --from=builder /app ./

EXPOSE 3000

CMD ["pnpm", "start"]
