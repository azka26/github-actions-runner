#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
TARGET_DIR="${HOME}/.config/containers/systemd"
ENV_FILE="${TARGET_DIR}/github-actions-runner.env"
SERVICE_NAME="github-actions-runner"
IMAGE="docker.io/azka2606/github-actions-runner:latest"

prompt_required() {
  local prompt="$1"
  local value=""

  while [ -z "${value}" ]; do
    read -r -p "${prompt}: " value
    if [ -z "${value}" ]; then
      echo "Nilai tidak boleh kosong."
    fi
  done

  printf '%s' "${value}"
}

prompt_secret() {
  local prompt="$1"
  local value=""

  while [ -z "${value}" ]; do
    read -r -s -p "${prompt}: " value
    echo
    if [ -z "${value}" ]; then
      echo "Nilai tidak boleh kosong."
    fi
  done

  printf '%s' "${value}"
}

install -d "${TARGET_DIR}"

github_url="$(prompt_required 'GitHub runner URL')"
github_token="$(prompt_secret 'GitHub runner token')"
runner_name="$(prompt_required 'Nama runner')"

install -m 0644 "${SOURCE_DIR}/github-actions-runner.container" "${TARGET_DIR}/github-actions-runner.container"
install -m 0644 "${SOURCE_DIR}/github-actions-runner.network" "${TARGET_DIR}/github-actions-runner.network"

cat > "${ENV_FILE}" <<EOF
GIT_RUNNER_URL=${github_url}
GIT_RUNNER_TOKEN=${github_token}
GIT_RUNNER_NAME=${runner_name}
GIT_RUNNER_LABEL=self-hosted,linux,x64,podman
EOF
chmod 0600 "${ENV_FILE}"

echo "Quadlet sudah dipasang ke ${TARGET_DIR}."
echo "Environment runner ditulis ke ${ENV_FILE}."

podman pull "${IMAGE}"
echo "Image ${IMAGE} sudah ditarik."

systemctl --user daemon-reload
echo "Systemd user daemon sudah di-reload."

if systemctl --user is-active --quiet "${SERVICE_NAME}"; then
  systemctl --user stop "${SERVICE_NAME}"
  echo "Service ${SERVICE_NAME} sudah dihentikan."
else
  echo "Service ${SERVICE_NAME} tidak sedang berjalan, skip stop."
fi

systemctl --user start "${SERVICE_NAME}"
echo "Service ${SERVICE_NAME} sudah dijalankan."
