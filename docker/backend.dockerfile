# 프론트엔드 빌드 스테이지
FROM docker.io/library/node:lts as frontend-builder

WORKDIR /app
COPY rin_agent_front ./rin_agent_front

WORKDIR /app/rin_agent_front
RUN npm install --frozen-lockfile
RUN npm run build

# Rust 백엔드 빌드 스테이지
FROM docker.io/library/rust:latest as builder

WORKDIR /app
COPY . .

# 빌드 시 필요한 의존성 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Cargo 캐시를 활용하기 위해 의존성만 먼저 컴파일
WORKDIR /app/rin_agent
RUN cargo build --release -p rin_agent 2>&1 | head -20 || true

# 프론트엔드 빌드 결과 복사
COPY --from=frontend-builder /app/rin_agent_front/build ./rin_agent/static

# rin_agent 바이너리 빌드
RUN cargo build --release -p rin_agent

# 실행 스테이지
FROM docker.io/library/debian:bookworm-slim

WORKDIR /app

# 런타임 의존성 설치 및 비루트 사용자 생성
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 appuser

# 빌드된 바이너리 복사
COPY --from=builder /app/target/release/rin_agent /usr/local/bin/rin_agent

# 프론트엔드 정적 파일 복사
COPY --from=builder /app/rin_agent/rin_agent/static /app/static

# 권한 설정
RUN chmod +x /usr/local/bin/rin_agent && \
    chown -R appuser:appuser /app

# 비루트 사용자로 실행
USER appuser

# 포트 설정
EXPOSE 8000

# 헬스 체크 (Podman 호환 버전)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD test -f /proc/$$/stat || exit 1

# 애플리케이션 시작
CMD ["rin_agent"]