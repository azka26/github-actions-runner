#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
TARGET_DIR="${HOME}/.config/containers/systemd"
ENV_FILE="${TARGET_DIR}/github-actions-runner.env"
SERVICE_NAME="github-actions-runner"
IMAGE="docker.io/azka2606/github-actions-runner:latest"

CURRENT_USER="$(id -un)"
CURRENT_UID="$(id -u)"

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
    read -r -p "${prompt}: " value
    if [ -z "${value}" ]; then
      echo "Nilai tidak boleh kosong."
    fi
  done

  printf '%s' "${value}"
}

enable_linger() {
  if loginctl show-user "${CURRENT_USER}" -p Linger 2>/dev/null | grep -q '^Linger=yes$'; then
    echo "Linger untuk user ${CURRENT_USER} sudah aktif."
    return
  fi

  echo "Mengaktifkan linger untuk user ${CURRENT_USER}..."

  if [ "${EUID}" -eq 0 ]; then
    loginctl enable-linger "${CURRENT_USER}"
  else
    sudo loginctl enable-linger "${CURRENT_USER}"
  fi

  echo "Linger untuk user ${CURRENT_USER} sudah aktif."
}

install -d "${TARGET_DIR}"

github_url="$(prompt_required 'GitHub runner URL')"
github_token="$(prompt_secret 'GitHub runner token')"
runner_name="$(prompt_required 'Nama runner')"

enable_linger

install -m 0644 "${SOURCE_DIR}/github-actions-runner.container" "${TARGET_DIR}/github-actions-runner.container"
install -m 0644 "${SOURCE_DIR}/github-actions-runner.network" "${TARGET_DIR}/github-actions-runner.network"

cat > "${ENV_FILE}" <<EOF
GIT_RUNNER_URL=${github_url}
GIT_RUNNER_TOKEN=${github_token}
GIT_RUNNER_NAME=${runner_name}
GIT_RUNNER_LABEL=self-hosted,linux,x64,podman,build-self-hosted,netcore-build,node-build
EOF
chmod 0600 "${ENV_FILE}"

echo "Quadlet sudah dipasang ke ${TARGET_DIR}."
echo "Environment runner ditulis ke ${ENV_FILE}."

podman pull "${IMAGE}"
echo "Image ${IMAGE} sudah ditarik."

systemctl --user enable --now podman.socket
echo "Podman user socket sudah aktif."

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

echo
echo "Status:"
echo "  User              : ${CURRENT_USER}"
echo "  UID               : ${CURRENT_UID}"
echo "  Linger            : $(loginctl show-user "${CURRENT_USER}" -p Linger 2>/dev/null | cut -d= -f2 || echo unknown)"
echo "  XDG_RUNTIME_DIR   : ${XDG_RUNTIME_DIR:-/run/user/${CURRENT_UID}}"
echo
echo "Cek service dengan:"
echo "  systemctl --user status ${SERVICE_NAME}"
echo "  systemctl --user status podman.socket"