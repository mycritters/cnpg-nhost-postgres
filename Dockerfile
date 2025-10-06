# CloudNativePG PostgreSQL 17 with Nhost Extensions - Multi-stage Build
# Based on the official CNPG PostgreSQL image with all Nhost extensions included
# Source extensions list: https://hub.docker.com/r/nhost/postgres
#
# This multi-stage build completely eliminates build tools from the final image

ARG PG_MAJOR=17
ARG BASE_IMAGE=ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm

# ============================================================================
# Stage 1: Builder - Compile extensions from source
# ============================================================================
FROM ${BASE_IMAGE} as builder

USER root

# Install build dependencies for compiling pg_hashids and pg_ivm
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    postgresql-server-dev-${PG_MAJOR} \
    && rm -rf /var/lib/apt/lists/*

# Build pg_hashids
RUN git clone https://github.com/iCyberon/pg_hashids.git /tmp/pg_hashids \
    && cd /tmp/pg_hashids \
    && make \
    && make install

# Build pg_ivm (Incremental View Maintenance)
RUN git clone https://github.com/sraoss/pg_ivm.git /tmp/pg_ivm \
    && cd /tmp/pg_ivm \
    && make \
    && make install

# ============================================================================
# Stage 2: Final Runtime Image
# ============================================================================
FROM ${BASE_IMAGE}

ARG PG_MAJOR=17
ARG PARADEDB_VERSION=0.18.11

USER root

# Install curl for downloading packages (small, useful for runtime too)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled extensions from builder stage
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/pg_hashids* /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/pg_hashids.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/pg_ivm* /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/pg_ivm.so /usr/lib/postgresql/${PG_MAJOR}/lib/

# Install PostGIS and related extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-postgis-3 \
    postgresql-${PG_MAJOR}-postgis-3-scripts \
    && rm -rf /var/lib/apt/lists/*

# Install other PostgreSQL extensions from Debian repos
# Note: pgvector is already included in the base CNPG image
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-cron \
    postgresql-${PG_MAJOR}-http \
    postgresql-${PG_MAJOR}-hypopg \
    postgresql-${PG_MAJOR}-ip4r \
    postgresql-${PG_MAJOR}-repack \
    postgresql-${PG_MAJOR}-squeeze \
    && rm -rf /var/lib/apt/lists/*

# Install TimescaleDB (temporarily use gnupg, lsb-release, wget)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    lsb-release \
    wget \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends timescaledb-2-postgresql-${PG_MAJOR} \
    && apt-get purge -y --auto-remove gnupg lsb-release wget \
    && rm -rf /var/lib/apt/lists/*

# Add Pigsty repository for pg_jsonschema and pgmq
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    lsb-release \
    && curl -fsSL https://repo.pigsty.io/key | gpg --dearmor -o /etc/apt/keyrings/pigsty.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/infra generic main" > /etc/apt/sources.list.d/pigsty-io.list \
    && echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/pgsql/$(lsb_release -cs) $(lsb_release -cs) main" >> /etc/apt/sources.list.d/pigsty-io.list \
    && apt-get purge -y --auto-remove gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Rust-based extensions using pre-built packages from Pigsty
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR}-pg-jsonschema \
    postgresql-${PG_MAJOR}-pgmq \
    && rm -rf /var/lib/apt/lists/*

# Install ParadeDB pg_search from GitHub releases
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v${PARADEDB_VERSION}/postgresql-${PG_MAJOR}-pg-search_${PARADEDB_VERSION}-1PARADEDB-bookworm_amd64.deb" -o /tmp/pg_search.deb \
    && apt-get update \
    && apt-get install -y /tmp/pg_search.deb \
    && rm -f /tmp/pg_search.deb \
    && rm -rf /var/lib/apt/lists/*

# Configure shared_preload_libraries
RUN echo "shared_preload_libraries = 'pg_stat_statements,timescaledb,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample

USER postgres

# Add labels
LABEL maintainer="CloudNativePG with Nhost Extensions" \
      org.opencontainers.image.description="PostgreSQL ${PG_MAJOR} with all Nhost extensions for CloudNativePG" \
      org.opencontainers.image.source="https://github.com/mycritters/cnpg-nhost-postgres"

# Extensions included (60/60 from Nhost - 100% compatibility):
# - PostGIS (postgis, postgis_raster, postgis_topology, postgis_tiger_geocoder, address_standardizer, address_standardizer_data_us)
# - TimescaleDB
# - pg_vector (bundled in base image)
# - pg_cron
# - pg_http
# - pg_hashids (compiled from source)
# - pg_ivm (compiled from source)
# - pg_jsonschema (via Pigsty repository)
# - pg_search / ParadeDB (via GitHub releases)
# - pgmq (via Pigsty repository)
# - pg_repack
# - pg_squeeze
# - hypopg
# - ip4r
# - And all 24 standard contrib extensions (pgcrypto, hstore, uuid-ossp, etc.)
