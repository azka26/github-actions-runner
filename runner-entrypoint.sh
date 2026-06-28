#!/usr/bin/env bash
set -euo pipefail

required_env="GIT_RUNNER_URL GIT_RUNNER_NAME GIT_RUNNER_LABEL"
for env_name in ${required_env}; do
  if [ -z "${!env_name:-}" ]; then
    echo "Missing required environment variable: ${env_name}" >&2
    exit 1
  fi
done

RUNNER_HOME="${RUNNER_HOME:-/home/runner/actions-runner}"
RUNNER_ARCHIVE="${RUNNER_ARCHIVE:-/opt/actions-runner/actions-runner.tar.gz}"

mkdir -p "${RUNNER_HOME}"
cd "${RUNNER_HOME}"

if [ ! -x ./run.sh ] || [ ! -x ./config.sh ]; then
  if [ ! -r "${RUNNER_ARCHIVE}" ]; then
    echo "Missing runner archive: ${RUNNER_ARCHIVE}" >&2
    exit 1
  fi

  echo "Extracting GitHub Actions runner into ${RUNNER_HOME}..."
  tar xzf "${RUNNER_ARCHIVE}" --no-same-owner
fi

if [ ! -f .runner ] || [ ! -f .credentials ]; then
  if [ -z "${GIT_RUNNER_TOKEN:-}" ]; then
    echo "Missing required environment variable for first-time runner registration: GIT_RUNNER_TOKEN" >&2
    exit 1
  fi

  ./config.sh \
    --unattended \
    --replace \
    --url "${GIT_RUNNER_URL}" \
    --token "${GIT_RUNNER_TOKEN}" \
    --name "${GIT_RUNNER_NAME}" \
    --labels "${GIT_RUNNER_LABEL}" \
    --work "_work"
else
  echo "Existing GitHub Actions runner configuration found; reusing ${RUNNER_HOME}."
fi

cleanup() {
  trap - EXIT INT TERM
  if [ -n "${runner_pid:-}" ]; then
    kill "${runner_pid}" 2>/dev/null || true
    wait "${runner_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

./run.sh &
runner_pid=$!
wait "${runner_pid}"
