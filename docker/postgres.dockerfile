FROM postgres:18

# Install build dependencies and extensions
RUN apt-get update && apt-get install -y \
    postgresql-server-dev-18 \
    build-essential \
    git \
    curl \
    ca-certificates \
    postgresql-plpython3-18 \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector
RUN git clone https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd .. \
    && rm -rf pgvector
