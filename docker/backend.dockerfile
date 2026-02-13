# 빌드 스테이지
FROM rust:latest as builder

WORKDIR /app
COPY . .

# 빌드 시 필요한 의존성 설치
RUN apt-get update && apt-get install -y \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# rin_agent 바이너리 빌드
RUN cargo build --release -p rin_agent

# 실행 스테이지
FROM debian:bookworm-slim

WORKDIR /app

# 런타임 의존성 설치
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 빌드된 바이너리 복사
COPY --from=builder /app/target/release/rin_agent /usr/local/bin/rin_agent

# 필요한 정적 파일 복사 (있을 경우)
COPY rin_agent/rin_agent/static /app/static

# 포트 설정
EXPOSE 8000

# 헬스 체크
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD ps aux | grep "[r]in_agent" || exit 1

# 애플리케이션 시작
CMD ["rin_agent"]