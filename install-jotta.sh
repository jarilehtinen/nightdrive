#!/bin/bash
# Jottacloud sync (jotta-cli, Sync folder ~/Jotta). Not rclone: it doesn't work with the Sync section.
# Note: the newest package (0.17.176206) is signed with a key the repo does not publish (2026-10) → install 0.17.159692,
# which passes the check. Once the key is published, the version pin can be removed.
set -euo pipefail
sudo tee /etc/yum.repos.d/JottaCLI.repo >/dev/null <<'REPO'
[jotta-cli]
name=Jotta CLI
baseurl=https://repo.jotta.cloud/redhat
enabled=1
gpgcheck=1
gpgkey=https://repo.jotta.cloud/public.gpg
REPO
sudo dnf install -y jotta-cli-0.17.159692
sudo dnf versionlock add jotta-cli   # otherwise `dnf upgrade` tries 0.17.176206 and the whole upgrade fails on the signature error
run_jottad
cat <<'MSG'

Done. Still to do by hand (interactive):
  jotta-cli login                          # one-time token: Jottacloud › Settings › Security
  jotta-cli sync setup --root ~/Jotta      # reporting: off / stackonly
  jotta-cli sync start
  jotta-cli status
MSG
