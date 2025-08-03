#!/bin/bash

set -e

echo "Initializing Vault cluster..."

# Set Vault address to the first voting node
export VAULT_ADDR="http://192.168.56.10:8200"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
while ! curl -s $VAULT_ADDR/v1/sys/health >/dev/null 2>&1; do
    sleep 2
done

# Initialize Vault
echo "Initializing Vault..."
vault operator init -key-shares=5 -key-threshold=3 > /vagrant/init-output.txt

# Extract unseal keys and root token
grep "Unseal Key" /vagrant/init-output.txt | awk '{print $4}' > /vagrant/unseal-keys.txt
grep "Initial Root Token" /vagrant/init-output.txt | awk '{print $4}' > /vagrant/root-token.txt

# Set proper permissions
chmod 600 /vagrant/root-token.txt
chmod 600 /vagrant/unseal-keys.txt

echo "Vault initialized successfully!"
echo "Unseal keys saved to /vagrant/unseal-keys.txt"
echo "Root token saved to /vagrant/root-token.txt"

# Unseal the first node
echo "Unsealing first node..."
head -3 /vagrant/unseal-keys.txt | while read key; do
    vault operator unseal "$key"
done

# Set the root token for this session
export VAULT_TOKEN=$(cat /vagrant/root-token.txt)
echo "Root token set for current session"

# Configure token for vagrant user on all nodes
echo "Configuring VAULT_TOKEN for vagrant user on all nodes..."
for ip in 192.168.56.10 192.168.56.11 192.168.56.20 192.168.56.21 192.168.56.30 192.168.56.31; do
    echo "Configuring $ip..."
    ssh -o StrictHostKeyChecking=no vagrant@$ip "~/set-vault-token.sh" 2>/dev/null || echo "Could not configure $ip (may not be ready)"
done

echo "First node unsealed and tokens configured."
echo "You can now unseal other nodes using the unseal script."
echo "All vagrant users should have VAULT_ADDR and VAULT_TOKEN configured."