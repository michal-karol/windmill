# DB Password and URL, the password is changed at runtime, cloud init feteches the password from key vauilt and replaces it with sed -i
POSTGRES_PASSWORD=CHANGEME
DATABASE_URL=postgres://postgres:CHANGEME@db/windmill?sslmode=disable

# For Enterprise Edition, use:
# WM_IMAGE=ghcr.io/windmill-labs/windmill-ee:main
# Community Edition — pinned 2026-06-24
# Latest tags: https://github.com/windmill-labs/windmill/releases
WM_IMAGE=ghcr.io/windmill-labs/windmill:1.741.0

# LSP, Multiplayer, Debugger sidecar — must match WM_IMAGE version
# Latest tags: https://github.com/windmill-labs/windmill/pkgs/container/windmill-extra
WM_EXTRA_IMAGE=ghcr.io/windmill-labs/windmill-extra:1.741.0

# Custom Caddy build with Layer 4 plugin — pinned 2026-06-24
# Latest tags: https://github.com/windmill-labs/windmill/pkgs/container/caddy-l4
WM_CADDY_IMAGE=ghcr.io/windmill-labs/caddy-l4:sha-989c9e6

# To use another port than :80, setup the Caddyfile and the caddy section of the docker-compose to your needs: https://caddyserver.com/docs/getting-started
# To have caddy take care of automatic TLS

# Base URL for Caddy ACME certificate provisioning
# Must match the Azure public IP FQDN — set by Terraform via templatefile()
BASE_URL=${base_url}

# To rotate logs, set the following variables:
#LOG_MAX_SIZE=10m
#LOG_MAX_FILE=3