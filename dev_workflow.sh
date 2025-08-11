#!/usr/bin/env bash
set -e

export VAULT_ADDR='http://127.0.0.1:8200'

# Simulate OIDC login using vault's OIDC helper (dev flow)
echo "Start OIDC login flow (this opens a browser)"
# Use the vault CLI to start OIDC login. This will open a browser where you log into Keycloak (dev1/devpass)
vault login -method=oidc -path=oidc || true

# In lab mode, user will be logged in and have a token in the env
VAULT_TOKEN=$(vault print token || true)
if [ -z "$VAULT_TOKEN" ]; then
  echo "Could not get vault token from OIDC flow. Trying to use root for demo..."
  export VAULT_TOKEN=root
else
  export VAULT_TOKEN=$VAULT_TOKEN
fi

# Read the fake GitHub token from KV (simulate GitHub App access token issuance)
echo "Reading short-lived GitHub-like token from Vault KV (demo)"
vault kv get -field=token kv/github

# Generate an SSH cert (developer provides their public key). We'll generate a keypair for demo
KEYDIR=./dev_key
mkdir -p $KEYDIR
ssh-keygen -t rsa -b 2048 -f $KEYDIR/id_rsa -N "" -C "dev1@lab" >/dev/null

pubkey=$(cat $KEYDIR/id_rsa.pub)

echo "Requesting SSH cert from Vault (ssh/sign/dev-access)..."
vault write -format=json ssh/sign/dev-access public_key="$pubkey" > /tmp/ssh_signed.json

cert=$(jq -r '.data.signed_key' /tmp/ssh_signed.json)

# Save signed cert
echo "$cert" > $KEYDIR/id_rsa-cert.pub
chmod 600 $KEYDIR/id_rsa*

cat <<EOF

Developer keys created in $KEYDIR
Private key: $KEYDIR/id_rsa
Public key:  $KEYDIR/id_rsa.pub
Signed cert: $KEYDIR/id_rsa-cert.pub

Use the signed cert to authenticate to a host that trusts Vault CA (demo only).

EOF