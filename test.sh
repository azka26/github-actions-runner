#!/usr/bin/env bash
set -euo pipefail

podman run --rm -it \
    --name github-actions-runner-test \
    --userns=keep-id \
    --security-opt label=disable \
    --env GIT_RUNNER_URL="https://github.com/azka26/test-repo" \
    --env GIT_RUNNER_TOKEN="AD76PWRZWPDE6KGO2Q4GGEDKOHEGS" \
    --env GIT_RUNNER_NAME="runner-podman-test-01" \
    --env GIT_RUNNER_LABEL="self-hosted,linux,x64,podman" \
    --volume "$XDG_RUNTIME_DIR/podman/podman.sock:/run/podman/podman.sock" \
    --volume github-actions-runner-test-data:/home/runner/actions-runner:U \
    localhost/github-actions-runner:latest
