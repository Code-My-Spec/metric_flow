# Dockerfile for MetricFlow Phoenix app

ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.0.1
ARG DEBIAN_VERSION=bookworm-20260223-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Mix's git-sourced deps fail over HTTP/2 against GitHub from this image.
RUN git config --global http.version HTTP/1.1

# sops decrypts envs/<env>.enc.env at boot. `dpkg --print-architecture`
# matches sops' release asset naming, so this follows the image's arch.
ARG SOPS_VERSION=3.9.4
RUN curl -fsSL -o /usr/local/bin/sops \
      "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.$(dpkg --print-architecture)" && \
    chmod +x /usr/local/bin/sops && \
    sops --version --disable-version-check

ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy all application code
COPY priv priv
COPY lib lib
COPY assets assets

# Copy runtime config
COPY config/runtime.exs config/
COPY rel rel

# Encrypted environments travel in the image; the key arrives at run time
# as SOPS_AGE_KEY.
COPY envs rel/overlays/envs

# Install npm dependencies for JS assets
RUN cd assets && npm install && cd ..

# Compile and build assets
RUN mix compile
RUN mix assets.deploy

# Build release
RUN mix release

# ---- Runner stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/metric_flow ./
COPY --from=builder /usr/local/bin/sops /usr/local/bin/sops

# CodeMySpec builds this image without kamal, so kamal's own label is set here.
LABEL service="metric-flow"

USER nobody

# bin/boot decrypts envs/<APP_ENV>.enc.env, then execs bin/server.
CMD ["/app/bin/boot"]
