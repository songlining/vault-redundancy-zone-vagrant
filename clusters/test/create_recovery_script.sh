sudo tee /usr/local/bin/vault-complete-recovery.sh > /dev/null << 'EOF'
#!/bin/bash

set -e  # Exit on any error

echo "=== Vault Node Recovery Process ==="

echo "Step 1: Stopping Vault service..."
sudo systemctl stop vault

echo "Step 2: Cleaning up Vault data..."
sudo rm -rf /opt/vault/data/*
sudo rm -rf /opt/vault/raft
sudo chown -R vault:vault /opt/vault/data

echo "Step 3: Starting Vault service..."
sudo systemctl start vault

echo "Step 4: Waiting for Vault to start..."
sleep 15

echo "Step 5: Checking Vault status..."
vault status

echo "Step 6: Rejoining cluster as non-voter..."
vault operator raft join -retry -non-voter \
  -leader-ca-cert=/opt/vault/tls/tls.crt \
  http://192.168.56.20:8200

echo "Step 7: Waiting for join to complete..."
sleep 5

echo "Step 8: Unsealing Vault..."
if [ -f "/vagrant/init.json" ]; then
    UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vagrant/init.json)
    UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vagrant/init.json)
    
    vault operator unseal "$UNSEAL_KEY_1"
    vault operator unseal "$UNSEAL_KEY_2"
    
    echo "=== Recovery Complete! ==="
    echo "Final status:"
    vault status
else
    echo "Error: /vagrant/init.json not found"
    echo "Please unseal manually with your unseal keys"
    exit 1
fi
EOF

# Make it executable
sudo chmod +x /usr/local/bin/vault-complete-recovery.sh

# Run the recovery
/usr/local/bin/vault-complete-recovery.sh