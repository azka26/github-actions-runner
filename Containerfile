# syntax=docker/dockerfile:1
# Update image digests deliberately when taking base-image security updates.
ARG DOCKER_CLI_IMAGE=docker.io/library/docker:28.5-cli@sha256:625d9431a9f54c5a2bc90f24f0e1c3d55b1349fd857dd85035f98c2c9acbdd4d
ARG UBUNTU_IMAGE=docker.io/library/ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7
FROM ${DOCKER_CLI_IMAGE} AS docker-cli

FROM ${UBUNTU_IMAGE} AS runner-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG RUNNER_VERSION=2.337.0
ARG RUNNER_SHA256=70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613

ENV DOCKER_HOST=unix:///var/run/docker.sock
# Docker 28's legacy build client uses Podman's compatible build API.
# Buildx/BuildKit and Compose plugins are intentionally not included.
ENV DOCKER_BUILDKIT=0
ENV RUNNER_HOME=/home/runner/actions-runner
ENV RUNNER_ARCHIVE=/opt/actions-runner/actions-runner.tar.gz
ENV PATH=/home/runner/.local/bin:${PATH}

# The runner archive and tool checksums below are for linux/amd64 only.
RUN test "$(dpkg --print-architecture)" = amd64 \
    || { echo "This image requires --platform linux/amd64" >&2; exit 1; }

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gh \
        git \
        jq \
        libgssapi-krb5-2 \
        libicu78 \
        libkrb5-3 \
        liblttng-ust1 \
        libssl3 \
        sudo \
        tar \
        tini \
        wget \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

RUN useradd --create-home --shell /bin/bash runner \
    && usermod -aG sudo runner \
    && mkdir -p /opt/actions-runner /home/runner/actions-runner \
    && chown runner:runner /home/runner/actions-runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

RUN curl -fsSL --retry 3 \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
        -o "${RUNNER_ARCHIVE}" \
    && echo "${RUNNER_SHA256}  ${RUNNER_ARCHIVE}" | sha256sum -c - \
    && chmod 0444 "${RUNNER_ARCHIVE}"

USER runner
WORKDIR /home/runner/actions-runner
RUN docker --version && gh --version && git --version
VOLUME ["/home/runner/actions-runner"]

# Tools are optional; build --target minimal to omit this stage.
FROM runner-base AS tools
ARG CODEX_VERSION=0.162.1
ARG CODEX_INSTALLER_SHA256=150e3cf675682efeaac115aa3747add3f27887896d04ce6d0b56478d8b428bf6
ARG CLAUDE_VERSION=2.1.300
ARG CLAUDE_SHA256=674deba0bba9aee479f4503c438b49303b6fdd304b9a471b14977aaec5215453
ARG CUX_VERSION=0.4.1
ARG CUX_SHA256=d336d1f8a6175265977f5a08ce53c20403e13752b90826df1128c29d89401df6
ARG CODEGRAPH_VERSION=1.6.2
ARG CODEGRAPH_SHA256=ef0af416092128fb1ccc723786000b7edf4a6971fe604acd08bf966e4f37b828

WORKDIR /tmp
RUN curl -fsSL --retry 3 \
        "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/install.sh" \
        -o /tmp/codex-install.sh \
    && echo "${CODEX_INSTALLER_SHA256}  /tmp/codex-install.sh" | sha256sum -c - \
    && CODEX_NON_INTERACTIVE=1 sh /tmp/codex-install.sh --release "${CODEX_VERSION}" \
    && rm /tmp/codex-install.sh

RUN curl -fsSL --retry 3 \
        "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/linux-x64/claude" \
        -o /tmp/claude \
    && echo "${CLAUDE_SHA256}  /tmp/claude" | sha256sum -c - \
    && install -m 0755 /tmp/claude /home/runner/.local/bin/claude \
    && rm /tmp/claude

RUN curl -fsSL --retry 3 \
        "https://github.com/inulute/cux/releases/download/v${CUX_VERSION}/cux-linux-amd64" \
        -o /tmp/cux \
    && echo "${CUX_SHA256}  /tmp/cux" | sha256sum -c - \
    && install -m 0755 /tmp/cux /home/runner/.local/bin/cux \
    && rm /tmp/cux

USER root
ENV CODEGRAPH_INSTALL_DIR=/opt/codegraph
ENV CODEGRAPH_BIN_DIR=/usr/local/bin
RUN curl -fsSL --retry 3 \
        "https://github.com/colbymchenry/codegraph/releases/download/v${CODEGRAPH_VERSION}/codegraph-linux-x64.tar.gz" \
        -o /tmp/codegraph.tar.gz \
    && echo "${CODEGRAPH_SHA256}  /tmp/codegraph.tar.gz" | sha256sum -c - \
    && mkdir -p "${CODEGRAPH_INSTALL_DIR}" \
    && tar xzf /tmp/codegraph.tar.gz -C "${CODEGRAPH_INSTALL_DIR}" --strip-components=1 --no-same-owner \
    && ln -s "${CODEGRAPH_INSTALL_DIR}/bin/codegraph" "${CODEGRAPH_BIN_DIR}/codegraph" \
    && rm /tmp/codegraph.tar.gz

RUN ln -s /home/runner/.local/bin/codex /usr/local/bin/codex \
    && ln -s /home/runner/.local/bin/claude /usr/local/bin/claude \
    && ln -s /home/runner/.local/bin/cux /usr/local/bin/cux

USER runner
WORKDIR /home/runner/actions-runner
RUN codex --version && claude --version && cux version && codegraph --version

# Copy the entrypoint last so edits do not invalidate tool-installation layers.
FROM runner-base AS minimal
COPY --chmod=0755 runner-entrypoint.sh /usr/local/bin/runner-entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/runner-entrypoint.sh"]

# Keep the complete image as the default target for existing builds.
FROM tools AS full
COPY --chmod=0755 runner-entrypoint.sh /usr/local/bin/runner-entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/runner-entrypoint.sh"]
