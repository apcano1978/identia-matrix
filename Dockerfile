# syntax=docker/dockerfile:1
# check=error=true

# Multi-stage Dockerfile for identia-matrix.
#   - `development`: gems for all groups, no asset precompile, no Thruster.
#   - `production`:  default target. Slim image with precompiled assets, jemalloc, Thruster.
#
# Build prod (default):  docker build -t identia_matrix .
# Build dev:             docker build --target development -t identia_matrix:dev .

ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Base packages shared by all stages. git y openssh-client los necesitará SERAPH
# en F10 para clonar los repositorios de cliente en su entorno efímero.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl git libjemalloc2 openssh-client postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle"


# === Development image =========================================================
FROM base AS development

ENV RAILS_ENV="development"

# Build deps required to compile native gem extensions (pg, etc.) +
# Chromium for headless system tests (Selenium driver) + fonts.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        build-essential libpq-dev libyaml-dev pkg-config \
        chromium chromium-driver fonts-liberation && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install gems for all groups (default + development + test).
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Code is bind-mounted at runtime via compose.yml; no COPY here.

EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]


# === Build image (production gems + assets) ====================================
FROM base AS build

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development" \
    JSON_DISABLE_SIMD="1"
# JSON_DISABLE_SIMD: la gema json (>=2.10) compila intrínsecas SIMD x86; al
# cruza-compilar amd64 desde Apple Silicon vía QEMU, esa compilación revienta
# (uncaught signal 5). Desactivar SIMD hace que json compile C plano y el build
# pase bajo emulación. Solo afecta a la compilación (perf de json marginal).

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# === Production image (final, default target) ==================================
FROM base AS production

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
