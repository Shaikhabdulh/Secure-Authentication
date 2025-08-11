#!/usr/bin/env bash
set -e

# Helper to wait for HTTP service
wait_for() {
  url=$1
  name=$2
  echo "Waiting for $name ($url) ..."
  until curl -sS $url >/dev/null; do sleep 1; done
  echo "$name is up"
}

# Wait for services
wait_for http://localhost:8080/ auth-server (Keycloak)
wait_for http://localhost:8200/ vault (Vault)
wait_for http://localhost:9200/ elasticsearch

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Enable OIDC auth (Keycloak)
vault auth enable oidc || true
vault write auth/oidc/config \
  oidc_discovery_url="http://keycloak:8080/realms/github-lab" \
  oidc_client_id="vault-client" \
  oidc_client_secret="vault-secret" \
  default_role="dev-role"

# Create policy that allows reading a fake github token and signing ssh keys
cat > github-access.hcl <<'EOF'
path "kv/data/github" {
  capabilities = ["read"]
}
path "ssh/sign/dev-access" {
  capabilities = ["create","read"]
}
EOF

vault policy write github-access github-access.hcl

# Enable KV for storing an example 'GitHub App' secret
vault secrets enable -path=kv kv || true
vault kv put kv/github token=ghp_fake_example_token_12345

# Enable SSH secrets engine and configure CA
vault secrets enable -path=ssh ssh || true
vault write -field=private_key ssh/config/ca generate_signing_key=true > /tmp/ssh_ca_key.pem || true

vault write ssh/roles/dev-access \
  key_type=ca \
  allowed_users='*' \
  default_extensions='{"permit-pty":""}' \
  ttl=1h || true

# Enable file audit log and point to mounted folder
mkdir -p ./vault_data
vault audit enable file file_path=/vault/file/audit.log || true

# Create OIDC role that maps Keycloak user to Vault policy
vault write auth/oidc/role/dev-role \
  user_claim="sub" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  policies="github-access" \
  ttl="1h"

echo "\nBootstrap complete. Vault root token: root"

echo "You can now run: ./dev_workflow.sh to simulate a developer login and token request"