# Run this from a healthy cluster member (not the node being removed)
sudo tee /tmp/remove-node.sh > /dev/null << 'EOF'
#!/bin/bash

NODE_TO_REMOVE="vault-rz1-nonvoting"

echo "=== Removing Node from Vault Cluster ==="

echo "Current cluster status:"
vault operator raft list-peers

echo ""
echo "Removing node: $NODE_TO_REMOVE"
vault operator raft remove-peer "$NODE_TO_REMOVE"

echo ""
echo "Updated cluster status:"
vault operator raft list-peers

echo ""
echo "Node removal complete!"
echo "The removed node will show 'Removed From Cluster: true' in its status."
EOF

chmod +x /tmp/remove-node.sh
/tmp/remove-node.sh