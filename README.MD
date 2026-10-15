# GitHub Actions runner dengan Podman host

Image memakai Docker CLI yang terhubung ke engine Podman di host melalui
`DOCKER_HOST=unix:///var/run/docker.sock`. Docker daemon dan Podman CLI tidak
dipasang di dalam image. Lihat [konfigurasi Quadlet](quadlet/README.md) untuk
mount socket, mengaktifkan `podman.socket`, dan menjalankan runner.

Image ini khusus **linux/amd64**. Build default menyertakan Codex, Claude, Cux,
dan CodeGraph. Target `minimal` menghilangkan keempat tools tersebut:

```bash
podman build --format docker --platform linux/amd64 --target full -f Containerfile -t localhost/github-actions-runner:latest .
podman build --format docker --platform linux/amd64 --target minimal -f Containerfile -t localhost/github-actions-runner:minimal .
```

`build.sh` tetap membuat varian lengkap dengan tag versi dan `latest`.
Format `docker` mempertahankan instruksi `SHELL` dengan opsi `pipefail`;
format OCI bawaan Podman tidak mendukung metadata `SHELL`.

Docker CLI memakai `DOCKER_BUILDKIT=0` agar `docker build` menggunakan API build
yang kompatibel dengan Podman. Compose dan Buildx tidak disertakan. Workflow
yang membutuhkan BuildKit perlu menyediakan builder dan konfigurasi tersendiri.

Versi tools, checksum unduhan, dan digest base image dikunci dalam `Containerfile`.
Saat memperbarui versi, perbarui checksum/digest terkait dari sumber rilis resmi.
Paket APT tetap mengikuti repository Ubuntu; build belum sepenuhnya reproducible.
Ambil pembaruan paket secara berkala dengan rebuild `--no-cache` setelah meninjau
pembaruan base image. Binary diperiksa dengan `--version` sebagai user `runner`
saat build. Tes koneksi ke engine dilakukan saat runtime:

```bash
docker version
docker info
```

Uji akses socket tanpa registrasi GitHub (jalankan dari host Linux/mesin Podman):

```bash
podman run --rm \
  --userns=keep-id:uid=1001,gid=1001 --user runner \
  --security-opt label=disable \
  --volume "${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock" \
  --entrypoint /bin/bash localhost/github-actions-runner:latest \
  -c 'set -e; id; docker version; docker run --rm docker.io/library/hello-world:latest'
```

UID/GID `runner` pada base image yang dikunci adalah `1001:1001`. Pemetaan
`keep-id` menggunakan UID/GID tersebut agar proses tetap berjalan sebagai
`runner` dan dapat mengakses socket rootless milik user host.

User `runner` tetap memiliki sudo tanpa password untuk kebutuhan workflow.
State registrasi disimpan di volume `/home/runner/actions-runner`.
