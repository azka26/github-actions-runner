# GitHub Actions Runner Quadlet

Copy these files into the Podman machine user systemd directory:

```bash
mkdir -p ~/.config/containers/systemd
cp github-actions-runner.container ~/.config/containers/systemd/
cp github-actions-runner.network ~/.config/containers/systemd/
cp github-actions-runner.env.example ~/.config/containers/systemd/github-actions-runner.env
```

Edit `~/.config/containers/systemd/github-actions-runner.env` and set the real GitHub runner URL, token, name, and labels.

The Quadlet file pulls the runner image from Docker Hub:

```bash
podman pull docker.io/azka2606/github-actions-runner:latest
```

Enable and start the user unit:

```bash
systemctl --user daemon-reload
systemctl --user enable --now github-actions-runner.service
systemctl --user status github-actions-runner.service
```

Runner files and GitHub registration state are stored in the `github-actions-runner-data` Podman volume. Keep that volume if the container is recreated and the runner will reuse the existing configuration.

View logs:

```bash
journalctl --user -u github-actions-runner.service -f
```
