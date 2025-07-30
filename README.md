# Vault Enterprise Three Redundancy Zone Cluster

This Vagrant setup creates a **4-node** Vault Enterprise cluster with three redundancy zones using VMware Desktop. The cluster features automatic initialization and unsealing during the build process.

## Prerequisites

1. Vagrant installed
2. VMware Desktop provider
3. Vault Enterprise license file (`vault.hclic`) in the project root
4. Sufficient system resources (8GB+ RAM recommended for 4 VMs)

## Setup

1. Place your `vault.hclic` license file in this directory
2. Start the cluster (this will automatically initialize and unseal all nodes):
   ```bash
   vagrant up --no-parallel
   ```
3. Wait for the provisioning to complete - you'll see a "Vault Cluster Ready" message

## Cluster Architecture

**Actual Configuration (4 nodes):**
- **RZ1**: vault-rz1-voting (192.168.56.10), vault-rz1-nonvoting (192.168.56.11)
- **RZ2**: vault-rz2-voting (192.168.56.20)
- **RZ3**: vault-rz3-voting (192.168.56.30)

**Note**: The current Vagrantfile only defines 4 nodes, to speed up the test. RZ2 and RZ3 each have only one voting node.

## Automatic Initialization Process

The cluster initialization happens automatically during `vagrant up` on the last node (vault-rz3-voting):

1. All 4 nodes are provisioned and Vault services started
2. System waits for all nodes to be ready and join the cluster
3. Vault is initialized with 3 key shares and 2 key threshold
4. Initialization data saved to `/vagrant/init.json` (JSON format)
5. Root token saved to `/vagrant/root-token.txt`
6. All nodes are automatically unsealed using the first 2 unseal keys
7. Environment variables configured for vagrant users

## Key Configuration Features

- **Raft Storage**: Integrated storage with autopilot enabled
- **Redundancy Zones**: Each node assigned to its respective RZ
- **Non-voting Nodes**: vault-rz1-nonvoting configured as non-voter
- **Retry Join**: All nodes configured to join via voting node leaders
- **Autopilot Settings**:
  - `cleanup_dead_servers = true`
  - `last_contact_threshold = "10s"`
  - `max_trailing_logs = 1000`
  - `min_quorum = 3`
  - `server_stabilization_time = "10s"`

## Accessing Vault

After `vagrant up` completes:

```bash
# SSH into any node
vagrant ssh vault-rz1-voting

# Vault environment is pre-configured
vault status
vault operator raft list-peers

# Use convenience scripts
~/vault-status.sh
~/set-vault-token.sh
```

- **Web UI**: http://192.168.56.10:8200 (or any node IP)
- **Root Token**: Available in `/vagrant/root-token.txt`
- **CLI Access**: `VAULT_ADDR` pre-configured, use `~/set-vault-token.sh` to set token

## VM Configuration

- **Provider**: VMware Desktop
- **Base Box**: gyptazy/ubuntu22.04-arm64
- **Memory**: 2GB per VM
- **CPUs**: 2 per VM
- **Network**: Private network (192.168.56.x)
- **Timeouts**: 10-minute boot and SSH timeouts
- **Tools**: Open VM Tools installed and configured

## Useful Commands

```bash
# Check cluster status
vault operator raft list-peers

# Check autopilot status
vault operator raft autopilot get-config

# Monitor cluster health
vault status

# View cluster members by redundancy zone
vault operator raft list-peers -format=json | jq '.data.config.servers[] | {id: .node_id, address: .address, leader: .leader, voter: .voter, redundancy_zone: .redundancy_zone}'

# Use convenience scripts
~/vault-status.sh  # Shows environment and cluster status
~/set-vault-token.sh  # Sets VAULT_TOKEN from root-token.txt
```

## Manual Operations (if needed)

```bash
# Manual initialization (only if needed)
vagrant ssh vault-rz1-voting
sudo /vagrant/scripts/init-cluster.sh

# Manual unseal (only if needed)
sudo /usr/local/bin/vault-unseal.sh

# Force restart hung VM
vagrant halt vault-rz1-voting --force
vagrant up vault-rz1-voting
```

## File Structure
```
vault-redundancy-zone-vagrant/
├── Vagrantfile              # Main VM configuration
├── vault.hclic             # Vault Enterprise license (required)
├── init.json               # Initialization data (auto-generated)
├── root-token.txt          # Root token (auto-generated)
├── scripts/
│   ├── setup-node.sh       # Node provisioning script
│   └── init-cluster.sh     # Manual initialization script
└── README.md               # This file
```


## Troubleshooting

### Common Issues
- **VM Hangs**: Use `vagrant halt <vm-name> --force` then `vagrant up <vm-name>`
- **Network Issues**: Check VMware Desktop networking settings
- **Resource Issues**: Ensure sufficient RAM (8GB+) for all VMs

### Debugging Commands
```bash
# Check Vault logs
sudo journalctl -u vault -f

# Verify license
vault read sys/license/status

# Check node status
vault operator raft list-peers

# View initialization output
cat /vagrant/init.json

# Check unseal status
vault status

# View root token
cat /vagrant/root-token.txt
```

### VM Management
```bash
# Check VM status
vagrant status

# Start VMs sequentially (recommended)
vagrant up --no-parallel

# Restart specific VM
vagrant reload vault-rz1-voting

# Destroy and recreate
vagrant destroy -f
vagrant up --no-parallel
```

## Security Notes

⚠️ **Important**: This setup is for development/testing only. In production:
- Use proper TLS certificates (currently disabled)
- Secure the unseal keys and root token
- Implement proper access controls
- Use auto-unseal with cloud KMS
- Enable audit logging
- Use proper network security
- Don't store credentials in shared folders