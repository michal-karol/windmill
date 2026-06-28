#cloud-config

# Mirror all cloud-init output to the serial console (in addition to the log
# file) so first-boot progress is visible through Azure boot diagnostics — no
# SSH or inbound ports required. Read it with:
#   az vm boot-diagnostics get-boot-log -g rg-windmill -n vm-windmill
output:
  all: '| tee -a /var/log/cloud-init-output.log /dev/console'

packages:
  - jq 
  - curl
  - ca-certificates
  - gnupg

# Create directory for windmill config files
bootcmd:
  - mkdir -p /opt/windmill

# Docker's apt repo is configured in runcmd (after its GPG key is installed) so
# the cloud-init `packages:` stage doesn't try to refresh an unsigned docker repo
# and skip installing jq/curl (jq is required for the Key Vault password fetch).
write_files:
  - path: /opt/windmill/docker-compose.yml
    permissions: '0644'
    encoding: b64
    content: ${docker_compose_b64}

  - path: /opt/windmill/Caddyfile
    permissions: '0644'
    encoding: b64
    content: ${caddyfile_b64}

  - path: /opt/windmill/.env
    permissions: '0600'
    encoding: b64
    content: ${env_b64}

    # Backup script
  - path: opt/windmill/backup.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      ACCOUNT="stwindmilltf"
      CONTAINER="backups"
      FILE="windmill-$(date -u +%Y%m%d-%H%M%S).sql.gz"
      TMP="/tmp/$FILE"
      # 1. Dump + compress from the running postgres container
      docker compose -f /opt/windmill/docker-compose.yml exec -T db \
      pg_dump -U postgres windmill | gzip > "$TMP"
      # 2. Managed identity token for Azure Storage
      TOKEN=$(curl -s -H "Metadata: true" \
        "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/" \
        | jq -r '.access_token')
      3. Upload via the Blob API
      curl -sf -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "x-ms-blob-type: BlockBlob" \
        -H "x-ms-version: 2021-08-06" \
        -H "Content-Type: application/gzip" \
        --data-binary @"$TMP" \
        "https://$ACCOUNT.blob.core.windows.net/$CONTAINER/$FILE"
      # 4. Remove the local temp file
      rm -f "$TMP"
  
  # Cron task for backup for 3am
  - path: /etc/cron.d/windmill-backup
    permissions: '0644'
    content: |
      # Windmill DB backup at 03:00 UTC
      0 3 * * * root /opt/windmill/backup.sh >> /var/log/windmill-backup.log 2>&1


runcmd:
  - 'echo "===== WINDMILL: installing docker ====="'
  # --> 1. Install Docker from Docker official apt repo <---

  # Add Docker's official GPG key:
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc

  # Configure Docker's apt repo now that the key exists (Suites derived from the
  # running release codename so it tracks the image instead of being hardcoded).
  - |
      . /etc/os-release
      printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.sources

  # Install the Docker packages
  - apt update
  - apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

  # Verify that Docker is running
  - systemctl enable --now docker

  # --> 2. Create working dir,and download Windmill files <--
  - mkdir -p /opt/windmill # Also in bootcmd — idempotent, kept for clarity

  - 'echo "===== WINDMILL: fetching db password from key vault ====="'
  # --> 3. Fetch Postgres password from Key Vault via managed identity (IMDS two-call flow)
  # and patch .env in place — all in one shell so variables persist <--
  - |
      TOKEN=$(curl -s -H "Metadata: true" --noproxy "*" \
        "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
        | jq -r '.access_token')
      DB_PASSWORD=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://${vault_name}.vault.azure.net/secrets/${secret_name}?api-version=7.0" \
        | jq -r '.value')
      sed -i 's|CHANGEME|'"$DB_PASSWORD"'|g' /opt/windmill/.env

  - 'echo "===== WINDMILL: preparing persistent data disk ====="'
  # --> 4. Mount the persistent data disk (LUN 0): holds the Postgres data AND the
  # Docker image cache so VM rebuilds don't re-pull ~1.5GB from ghcr. <--
  # Format ONLY if it has no filesystem yet, so data is preserved across VM
  # rebuilds. Mount persistently and make docker wait for the mount so a reboot
  # can't start Postgres against an unmounted (empty) directory.
  - |
      DISK=/dev/disk/azure/scsi1/lun0
      for i in $(seq 1 30); do [ -e "$DISK" ] && break; sleep 2; done
      if ! blkid "$DISK" >/dev/null 2>&1; then mkfs.ext4 -F "$DISK"; fi
      mkdir -p /datadisk
      UUID=$(blkid -s UUID -o value "$DISK")
      grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /datadisk ext4 defaults,nofail 0 2" >> /etc/fstab
      mount -a
      mkdir -p /datadisk/pgdata /datadisk/docker
      mkdir -p /etc/systemd/system/docker.service.d
      printf '[Unit]\nRequiresMountsFor=/datadisk\n' > /etc/systemd/system/docker.service.d/10-datadisk.conf
      # Move Docker's image store onto the persistent disk so cached layers survive
      # VM rebuilds (compose uses pull_policy: missing, so present images aren't re-pulled).
      mkdir -p /etc/docker
      printf '{"data-root":"/datadisk/docker"}\n' > /etc/docker/daemon.json
      systemctl daemon-reload
      systemctl restart docker

  - 'echo "===== WINDMILL: starting docker compose ====="'
  # --> 5. Start the stack <--
  - docker compose -f /opt/windmill/docker-compose.yml up -d
  # Drop any image not used by a running container (e.g. the previous WM_IMAGE
  # after a version bump) so the persistent image cache doesn't grow unbounded.
  # No-op when nothing changed, since all current images are in use.
  - docker image prune -af
  # Final marker the pipeline greps for to confirm first-boot completion.
  - 'echo "===== WINDMILL_CLOUDINIT_DONE ====="'