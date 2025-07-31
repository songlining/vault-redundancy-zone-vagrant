#!/bin/bash

set -e

RZ=$1
NODE_TYPE=$2
HOSTNAME=$(hostname)

echo "Setting up $HOSTNAME as $NODE_TYPE node in $RZ"

# Update system
#apt-get update
#apt-get upgrade -y

# Install open-vm-tools
apt-get install -y open-vm-tools
systemctl enable open-vm-tools
systemctl start open-vm-tools

# Install required packages
apt-get install -y curl wget gpg lsb-release software-properties-common jq

# Add HashiCorp GPG key and repository
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update package list and install Vault Enterprise
apt-get update
apt-get install -y vault-enterprise

# Create vault user and directories
useradd --system --home /etc/vault.d --shell /bin/false vault || true
mkdir -p /opt/vault/data
mkdir -p /etc/vault.d
chown -R vault:vault /opt/vault
chown -R vault:vault /etc/vault.d

# Copy license file
cp /vagrant/vault.hclic /etc/vault.d/
chown vault:vault /etc/vault.d/vault.hclic
chmod 640 /etc/vault.d/vault.hclic

NON_VOTER_CONFIG=""
if [ "$NODE_TYPE" = "nonvoting" ]; then
  NON_VOTER_CONFIG='non_voter = true'
fi

# Create Vault configuration with NODE_TYPE consideration
# Create Vault configuration
cat > /etc/vault.d/vault.hcl <<EOF
ui = true
cluster_name = "vault-cluster"
disable_mlock = true

api_addr = "http://$(hostname -I | awk '{print $2}'):8200"
cluster_addr = "http://$(hostname -I | awk '{print $2}'):8201"

storage "raft" {
  path = "/opt/vault/data"
  node_id = "$HOSTNAME"

  autopilot_redundancy_zone = "$RZ"
  $NON_VOTER_CONFIG
  
  retry_join {
    leader_api_addr = "http://192.168.56.10:8200"
  }
  retry_join {
    leader_api_addr = "http://192.168.56.20:8200"
  }
  retry_join {
    leader_api_addr = "http://192.168.56.30:8200"
  }
}

autopilot {
  cleanup_dead_servers = true
  last_contact_threshold = "10s"
  max_trailing_logs = 1000
  min_quorum = 3
  server_stabilization_time = "10s"
}

license_path = "/etc/vault.d/vault.hclic"

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true
}

log_level = "info"

audit "file" {
  path = "/var/log/vault_audit.log"
}

EOF

# Set proper permissions
touch /var/log/vault_audit.log
chown vault:vault /etc/vault.d/vault.hcl /var/log/vault_audit.log
chmod 640 /etc/vault.d/vault.hcl /var/log/vault_audit.log

# Create systemd service file
cat > /etc/systemd/system/vault.service << EOF
[Unit]
Description=HashiCorp Vault
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=notify
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Create unseal script
cat > /usr/local/bin/vault-unseal.sh << 'EOF'
#!/bin/bash

# Set Vault address
export VAULT_ADDR="http://localhost:8200"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
while ! curl -s http://localhost:8200/v1/sys/health >/dev/null 2>&1; do
    sleep 2
done

# Check if Vault is already unsealed
if curl -s http://localhost:8200/v1/sys/seal-status | grep -q '"sealed":false'; then
    echo "Vault is already unsealed"
    exit 0
fi

# Read unseal keys from file
if [ -f "/vagrant/init.json" ]; then
    echo "Found init.json, extracting unseal keys..."
    UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vagrant/init.json)
    UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vagrant/init.json)
    UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' /vagrant/init.json)
    
    # Unseal Vault
    echo "Unsealing Vault..."
    vault operator unseal "$UNSEAL_KEY_1"
    vault operator unseal "$UNSEAL_KEY_2"
    vault operator unseal "$UNSEAL_KEY_3"
    
    echo "Vault unsealing complete!"
else
    echo "Unseal keys not found at /vagrant/init.json"
    echo "Please initialize Vault first and save the unseal keys"
    exit 1
fi
EOF

chmod +x /usr/local/bin/vault-unseal.sh

# Create auto-unseal service
cat > /etc/systemd/system/vault-unseal.service << EOF
[Unit]
Description=Vault Auto Unseal
After=vault.service
Requires=vault.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/vault-unseal.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable vault
systemctl enable vault-unseal

# Start Vault service
systemctl start vault

# Configure environment variables for vagrant user
echo "# Vault Environment Variables" >> /home/vagrant/.bashrc
echo "export VAULT_ADDR=\"http://$(hostname -I | awk '{print $2}'):8200\"" >> /home/vagrant/.bashrc
echo "export VAULT_SKIP_VERIFY=true" >> /home/vagrant/.bashrc
echo "" >> /home/vagrant/.bashrc

# Create a script to set VAULT_TOKEN after initialization
cat > /home/vagrant/set-vault-token.sh << 'EOF'
#!/bin/bash
if [ -f "/vagrant/root-token.txt" ]; then
    export VAULT_TOKEN=$(cat /vagrant/root-token.txt)
    echo "export VAULT_TOKEN=$(cat /vagrant/root-token.txt)" >> ~/.bashrc
    echo "VAULT_TOKEN set from /vagrant/root-token.txt"
    echo "Current token: $VAULT_TOKEN"
else
    echo "Root token file not found. Please initialize Vault first."
fi
EOF

chmod +x /home/vagrant/set-vault-token.sh
chown vagrant:vagrant /home/vagrant/set-vault-token.sh

# Create a convenient vault status script
cat > /home/vagrant/vault-status.sh << 'EOF'
#!/bin/bash
echo "=== Vault Environment ==="
echo "VAULT_ADDR: $VAULT_ADDR"
echo "VAULT_TOKEN: ${VAULT_TOKEN:0:8}..."
echo ""
echo "=== Vault Status ==="
vault status
echo ""
echo "=== Cluster Status ==="
vault operator raft list-peers 2>/dev/null || echo "Not initialized or unsealed"
EOF

chmod +x /home/vagrant/vault-status.sh
chown vagrant:vagrant /home/vagrant/vault-status.sh

echo "Vault setup completed for $HOSTNAME"
echo "To unseal Vault, run: /usr/local/bin/vault-unseal.sh"
echo "After initialization, run: ~/set-vault-token.sh to configure VAULT_TOKEN"