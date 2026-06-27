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

  - 'echo "===== WINDMILL: starting docker compose ====="'
  # --> 4. Start the stack <--
  - docker compose -f /opt/windmill/docker-compose.yml up -d
  # Final marker the pipeline greps for to confirm first-boot completion.
  - 'echo "===== WINDMILL_CLOUDINIT_DONE ====="'