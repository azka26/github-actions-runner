# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG RUNNER_VERSION=2.335.1
ARG RUNNER_ARCH=x64
ARG RUNNER_SHA256=4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_ALLOW_RUNASROOT=0
ENV CONTAINER_HOST=unix:///run/podman/podman.sock
ENV DOCKER_HOST=unix:///run/podman/podman.sock
ENV RUNNER_HOME=/home/runner/actions-runner
ENV RUNNER_ARCHIVE=/opt/actions-runner/actions-runner.tar.gz

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        libgssapi-krb5-2 \
        libicu74 \
        libkrb5-3 \
        liblttng-ust1 \
        libssl3 \
        zlib1g \
        podman \
        sudo \
        tar \
        tini \
        docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash runner \
    && usermod -aG sudo,docker runner \
    && mkdir -p /run/podman \
    && chown runner:runner /run/podman \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

RUN mkdir -p /opt/actions-runner /home/runner/actions-runner \
    && chown -R runner:runner /home/runner/actions-runner

RUN curl -fsSL -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && echo "${RUNNER_SHA256}  actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" | sha256sum -c - \
    && mv ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz "${RUNNER_ARCHIVE}" \
    && chmod 0444 "${RUNNER_ARCHIVE}"

COPY runner-entrypoint.sh /usr/local/bin/runner-entrypoint.sh
RUN chmod +x /usr/local/bin/runner-entrypoint.sh

VOLUME ["/home/runner/actions-runner"]
WORKDIR /home/runner/actions-runner
USER runner
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/runner-entrypoint.sh"]
