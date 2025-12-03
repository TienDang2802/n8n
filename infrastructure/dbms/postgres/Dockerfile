ARG POSTGRES_VERSION=15-alpine
FROM postgres:${POSTGRES_VERSION}

# Set timezone
ENV TZ=Asia/Ho_Chi_Minh

# PostgreSQL performance tuning (can be overridden via environment variables)
ENV POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C"

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" || exit 1

EXPOSE 5432
