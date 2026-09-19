# syntax=docker/dockerfile:1.20
ARG RUST_VERSION=1.95
ARG CARGO_BUILD_FEATURES=default
ARG RUST_RELEASE_MODE=debug

ARG BUILDER_IMAGE=lukemathwalker/cargo-chef:latest-rust-${RUST_VERSION}
ARG RUNNER_IMAGE=debian:sid-slim

ARG UNAME=lemmy
ARG UID=1000
ARG GID=1000

# Chef
FROM ${BUILDER_IMAGE} AS chef

# `rust-toolchain.toml` pins `channel = "1.95"`, and rustup treats a channel as something to
# sync, so every build round-trips to static.rust-lang.org and fails outright on a restricted
# network. Point rustup at the toolchain that is already baked into the builder image instead.
# The image exports RUST_VERSION (the full `1.95.0`, not the `1.95` of the image tag), so the
# value is inherited rather than repeated here. Naming a toolchain without a host triple makes
# rustup resolve the triple for whatever architecture is building, so this is not arm64-only.
ENV RUSTUP_TOOLCHAIN=${RUST_VERSION}

# Fail loudly and offline if that toolchain is missing, instead of silently falling back to
# downloading the channel declared in rust-toolchain.toml. rustup resolves the bare version
# against the host triple, so match on the version prefix.
RUN set -eux; \
  rustup toolchain list | cut -d' ' -f1 | grep -q "^${RUSTUP_TOOLCHAIN}-"; \
  rustc --version

WORKDIR /lemmy

# Planner
FROM chef AS planner
COPY . . 
RUN cargo chef prepare --recipe-path recipe.json

# Builder
FROM chef AS builder

ARG CARGO_BUILD_FEATURES
ARG RUST_RELEASE_MODE
ARG RUSTFLAGS
ARG CI_PIPELINE_EVENT

COPY --from=planner /lemmy/recipe.json recipe.json
# Build dependencies - this is the caching Docker layer!
RUN if [ "${RUST_RELEASE_MODE}" = "release" ]; \
  then \
  cargo chef cook --recipe-path recipe.json --release --all-features; \
  else \
  cargo chef cook --recipe-path recipe.json; \
  fi 

COPY . .

# Release build

RUN if [ "${RUST_RELEASE_MODE}" = "release" ]; \
  then \
  cargo build --features "${CARGO_BUILD_FEATURES}" --release --all-features; \
  mv target/release/lemmy_server .; \
  else \
  cargo build --features "${CARGO_BUILD_FEATURES}"; \
  mv target/debug/lemmy_server .; \
  fi 

# Runner
FROM ${RUNNER_IMAGE} AS runner

# Add system packages that are needed: federation needs CA certificates, curl can be used for healthchecks
RUN apt update && apt install -y libssl-dev libpq-dev ca-certificates curl git

COPY --from=builder /lemmy/lemmy_server /usr/local/bin/lemmy_server
RUN chmod 0755 /usr/local/bin/lemmy_server

LABEL org.opencontainers.image.authors="The Lemmy Authors"
LABEL org.opencontainers.image.source="https://github.com/LemmyNet/lemmy"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"
LABEL org.opencontainers.image.description="A link aggregator and forum for the fediverse"

ARG UNAME
ARG GID
ARG UID

RUN groupadd -g ${GID} -o ${UNAME} && \
  useradd -m -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME}
USER $UNAME

ENTRYPOINT ["lemmy_server"]
EXPOSE 8536
STOPSIGNAL SIGTERM
