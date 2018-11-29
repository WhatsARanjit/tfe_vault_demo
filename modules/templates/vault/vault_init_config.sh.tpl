#!/bin/bash

# Vault variable defaults
export VERSION="0.11.2"
export GROUP=vault
export USER=vault
export COMMENT=Vault
export HOME="/srv/vault"
export VAULT_ADDR="http://0.0.0.0:8200"
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=root

curl https://raw.githubusercontent.com/hashicorp/guides-configuration/master/shared/scripts/base.sh | bash
curl https://raw.githubusercontent.com/hashicorp/guides-configuration/master/shared/scripts/setup-user.sh | bash

yum -y install unzip
curl https://raw.githubusercontent.com/hashicorp/guides-configuration/master/vault/scripts/install-vault.sh | bash

# Since this is dev mode, Vault starts unsealed. DO NOT USE IN PRODUCTION!
nohup /usr/local/bin/vault server -dev \
  -dev-root-token-id="root" \
  -dev-listen-address="0.0.0.0:8200" &

# Commands to configure Vault AWS auth method

echo "path \"kv1/nodejs_secret\" { 
    capabilities = [\"create\", \"read\", \"update\", \"delete\"]
    }" | vault policy write nodejs-app -

vault auth enable aws

vault write -force auth/aws/config/client

vault write auth/aws/role/nodejs-app-iam \
    auth_type=iam \
    bound_iam_principal_arn=arn:aws:iam::${aws_account_id}:role/* \
    policies=nodejs-app \
    max_ttl=1h

# Enable secret mount and write secret
vault secrets enable -path=kv1 -version=1 kv

vault write kv1/nodejs_secret value=ThisIsTheFirstSecret
