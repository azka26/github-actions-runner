#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_IMAGE="localhost/github-actions-runner:latest"
REMOTE_IMAGE="docker.io/azka2606/github-actions-runner"
TAGS_URL="https://hub.docker.com/v2/repositories/azka2606/github-actions-runner/tags?page_size=100"

cd "${SCRIPT_DIR}"

tags_json="$(curl -fsSL "${TAGS_URL}")"
latest_version="$(
  printf '%s' "${tags_json}" \
    | grep -Eo '"name":"v?[0-9]+\.[0-9]+\.[0-9]+"' \
    | sed 's/"name":"v\{0,1\}//; s/"//' \
    | sort -V \
    | tail -n 1 \
    || true
)"

if [ -z "${latest_version}" ]; then
  next_version="1.0.0"
else
  IFS='.' read -r major minor patch <<< "${latest_version}"
  next_version="${major}.${minor}.$((patch + 1))"
fi

podman build \
  -f Containerfile \
  -t "${LOCAL_IMAGE}" \
  -t "${REMOTE_IMAGE}:${next_version}" \
  -t "${REMOTE_IMAGE}:latest" \
  .

echo "Image sudah berhasil dibuat:"
echo "  ${LOCAL_IMAGE}"
echo "  ${REMOTE_IMAGE}:${next_version}"
echo "  ${REMOTE_IMAGE}:latest"
