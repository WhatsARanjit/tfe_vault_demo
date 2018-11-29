#!/bin/bash
 
# Get jq
yum install -q -y wget unzip ca-certificates
curl -s -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 > /usr/local/bin/jq
chmod +x /usr/local/bin/jq

# Install Vault
curl -L https://releases.hashicorp.com/vault/0.11.2/vault_0.11.2_linux_amd64.zip > /tmp/vault.zip
cd /tmp
unzip vault.zip
mv vault /usr/local/bin
chmod 0755 /usr/local/bin/vault
chown root:root /usr/local/bin/vault

export VAULT_ADDR=${vault_addr}
export VAULT_SKIP_VERIFY=true

# Login
vault auth root

# Install consul-template
curl -s --output /tmp/consul-template_0.19.4_linux_amd64.zip https://releases.hashicorp.com/consul-template/0.19.4/consul-template_0.19.4_linux_amd64.zip
unzip -o /tmp/consul-template_0.19.4_linux_amd64.zip -d /usr/local/bin/
chmod 0755 /usr/local/bin/consul-template
chown root:root /usr/local/bin/consul-template
mkdir -pm 0755 /etc/consul-template.d /opt/consul-template/data
chown -R root:root /etc/consul-template.d /opt/consul-template/data
chmod -R 0644 /etc/consul-template.d

# Consul template config
cat <<EOF > /etc/consul-template.d/config.hcl
vault {
  address = "${vault_addr}"
  grace = "15s"
  unwrap_token = false
  renew_token = false
}
template {
  source = "/etc/consul-template.d/config.ctmpl"
  destination = "/usr/src/app/config.js"
  perms = 0777
  create_dest_dirs = true
  error_on_missing_key = true
  backup = true
}
syslog {
  enabled = true
  facility = "1"
}
EOF

# Consul template file for app
cat <<EOF > /etc/consul-template.d/config.ctmpl
module.exports = {
  "vault_secret": "{{ with secret "kv1/nodejs_secret" }}{{ .Data.value }}{{ end }}"
};
EOF

# Create the systemd file
cat << EOF > /etc/systemd/system/consul-template.service
[Unit]
Description=Consul Template
Requires=network-online.target
After=network-online.target
[Service]
EnvironmentFile=/etc/vault-token
Restart=on-failure
ExecStart=/usr/local/bin/consul-template -config /etc/consul-template.d/config.hcl
ExecReload=/bin/kill -HUP ${"$"}MAINPID
KillSignal=SIGTERM
User=root
Group=root
[Install]
WantedBy=multi-user.target
EOF

systemctl disable consul-template.service

# Install NodeJS
yum update
curl -sL https://rpm.nodesource.com/setup_11.x | bash -
yum install -y nodejs npm
mkdir -p /usr/src/app
cd /usr/src/app
wget --content-disposition "https://raw.githubusercontent.com/hashicorp/vault-guides/master/identity/nodejs-consul-template/vault-si-demo/config.js"
wget --content-disposition "https://raw.githubusercontent.com/hashicorp/vault-guides/master/identity/nodejs-consul-template/vault-si-demo/index.js"
wget --content-disposition "https://raw.githubusercontent.com/hashicorp/vault-guides/master/identity/nodejs-consul-template/vault-si-demo/package.json"
npm install

cat <<EOF > /etc/systemd/system/nodejs.service
[Unit]
Description=Vault nodejs example
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/node /usr/src/app/index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl disable nodejs.service

# Login with Vault
VAULT_ADDR=${vault_addr} vault login root
VAULT_ADDR=${vault_addr} vault token create -policy=nodejs-app -ttl=30s -explicit-max-ttl=1m -field=token > /etc/vault-token
systemctl enable consul-template.service
systemctl restart consul-template.service

# Restart nodejs service
systemctl enable nodejs.service
systemctl restart nodejs.service
