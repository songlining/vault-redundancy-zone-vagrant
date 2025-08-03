# Vault Redundancy Zone Vagrant Setup
A comprehensive Vagrant environment for testing HashiCorp Vault Enterprise with redundancy zones and disaster recovery (DR) replication.

## Overview
This project creates two Vault Enterprise clusters:

- Primary Cluster ( cluster-pri ): Main production cluster with redundancy zones
- DR Cluster ( cluster-dr ): Disaster recovery cluster configured as DR secondary
Both clusters support multiple virtualization providers (VMware, VirtualBox, QEMU) and are configured with Raft storage backend and autopilot for automated cluster management. Only VMware provider is fully tested.  

## Architecture
### Primary Cluster (cluster-pri)
- vault-pri-rz1-s1 (192.168.56.10) - Voting node, Zone rz1
- vault-pri-rz1-s2 (192.168.56.11) - Non-voting node, Zone rz1
### DR Cluster (cluster-dr)
- vault-dr-rz1-s1 (192.168.56.110) - Voting node, Zone rz1
- vault-dr-rz1-s2 (192.168.56.111) - Non-voting node, Zone rz1
### Features
- ✅ Redundancy Zones : Nodes are distributed across zones for high availability
- ✅ Autopilot : Automated cluster management and dead server cleanup
- ✅ DR Replication : Primary-to-secondary disaster recovery setup
- ✅ Multi-Provider : Support for VMware, VirtualBox, and QEMU
- ✅ Enterprise Features : Vault Enterprise with license support
- ✅ Automated Setup : Complete cluster initialization and unsealing
## Prerequisites
### Required Software
- Vagrant (latest version)
- One of the following providers (only VMware is fully tested):
  - VMware Desktop (recommended)
  - VirtualBox
  - QEMU (for ARM64 Macs)
### Vault Enterprise License
- Place your vault.hclic license file in the project root directory
- The license will be automatically copied to all nodes
## Quick Start
### 1. Clone and Setup
```
git clone <repository-url>
cd vault-redundancy-zone-vagrant

# Add your Vault Enterprise license
cp /path/to/your/vault.hclic .
```
### 2. Choose Provider (Optional)
```
# Default is VMware, change if needed
export VAGRANT_PROVIDER=vmware    # or virtualbox, qemu
```
### 3. Start the Environment
```
# Start all VMs (this will take 10-15 minutes)
vagrant up

# Check status
vagrant status
```
### 4. Access the Clusters Primary Cluster
```
vagrant ssh vault-pri-rz1-s1
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat /vagrant/cluster-pri-root-token.txt)
vault status
``` 
### 5. Access the DR Cluster
```
vagrant ssh vault-dr-rz1-s1
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat /vagrant/cluster-dr-root-token.txt)
vault status
```
## Configuration Details
### Provider Configuration
The environment supports three providers with optimized settings:

```
# VMware (Default - Recommended)
VAGRANT_PROVIDER=vmware
# - Box: gyptazy/ubuntu22.04-arm64
# - Memory: 2GB per VM
# - CPUs: 2 per VM

# VirtualBox
VAGRANT_PROVIDER=virtualbox
# - Box: bento/ubuntu-20.04
# - Memory: 3GB per VM
# - CPUs: 2 per VM

# QEMU (ARM64 Macs)
VAGRANT_PROVIDER=qemu
# - Box: roboxes/ubuntu2204
# - Memory: 3GB per VM
# - CPUs: 2 per VM
```
### Vault Configuration
Each node is configured with:

- Storage : Raft with autopilot
- Listener : HTTP on port 8200 (TLS disabled for testing)
- Cluster : HTTPS on port 8201
- Audit : File-based audit logging
- License : Enterprise license from vault.hclic
### Autopilot Settings
```
autopilot {
  cleanup_dead_servers = true
  last_contact_threshold = "10s"
  max_trailing_logs = 1000
  min_quorum = 3
  server_stabilization_time = "10s"
}
```
## DR Replication Setup
The environment automatically configures DR replication:

1. Primary Cluster : Configured as DR primary
2. DR Cluster : Configured as DR secondary
3. Replication : Automatic sync between clusters
4. Unsealing : DR nodes use primary cluster's unseal keys
### DR Promotion (Disaster Scenario)
To promote the DR cluster in case of primary failure:

```
vagrant ssh vault-dr-rz1-s1
export VAULT_ADDR=http://localhost:8200
vault write -f sys/replication/dr/secondary/promote
```
## File Structure
```
vault-redundancy-zone-vagrant/
├── Vagrantfile              # Main Vagrant configuration
├── vault.hclic             # Vault Enterprise license (add this)
├── scripts/
│   ├── setup-node.sh       # Individual node setup script
│   └── init-cluster.sh     # Cluster initialization (if needed)
├── test/
│   ├── create_recovery_script.sh  # Node recovery testing
│   └── create_removal_script.sh   # Node removal testing
├── cluster-pri-ready       # Primary cluster ready marker
├── cluster-dr-ready        # DR cluster ready marker
├── cluster-pri-init.json   # Primary cluster init data
├── cluster-dr-init.json    # DR cluster init data
├── cluster-pri-root-token.txt  # Primary root token
├── cluster-dr-root-token.txt   # DR root token
└── dr-secondary-token.txt  # DR replication token
```
## Common Operations
### Check Cluster Status
```
# From any node
vault operator raft list-peers
vault operator raft autopilot state
```
### Check DR Replication Status
```
# From primary cluster
vault read sys/replication/dr/status

# From DR cluster
vault read sys/replication/dr/status
```
### Manual Unsealing (if needed)
```
# For primary cluster nodes
vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/cluster-pri-init.json)
vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/cluster-pri-init.json)

# For DR cluster nodes (use PRIMARY cluster keys!)
vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/cluster-pri-init.json)
vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/cluster-pri-init.json)
```
### Web UI Access
- Primary Cluster : http://192.168.56.10:8200
- DR Cluster : http://192.168.56.110:8200
## Testing and Recovery
### Node Recovery Testing
```
# SSH to any node and run
vagrant ssh vault-pri-rz1-s2
sudo /vagrant/test/create_recovery_script.sh
sudo /usr/local/bin/vault-complete-recovery.sh
```
### Node Removal Testing
```
# From a healthy cluster member
vagrant ssh vault-pri-rz1-s1
sudo /vagrant/test/create_removal_script.sh
```
## Troubleshooting
### Common Issues
1. License Missing
   
   ```
   # Error: license file not found
   # Solution: Add vault.hclic to project root
   cp /path/to/vault.hclic .
   vagrant reload --provision
   ```
2. DR Node Unsealing Fails
   
   ```
   # Use primary cluster's unseal keys, not DR cluster's
   vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/cluster-pri-init.json)
   ```
3. SSH Redirection Issues
   
   ```
   # Check VM status
   vagrant status
   
   # Reload problematic VM
   vagrant reload vault-dr-rz1-s2
   ```
### Logs and Debugging
```
# Vault service logs
sudo journalctl -u vault -f

# Vault audit logs
sudo tail -f /var/log/vault_audit.log

# Check Vault configuration
sudo cat /etc/vault.d/vault.hcl
```
## Cleanup
```
# Destroy all VMs
vagrant destroy -f

# Clean up generated files
rm -f cluster-*-ready cluster-*-init.json cluster-*-root-token.txt dr-secondary-token.txt
```
## Customization
### Adding More Zones
Uncomment and modify the zone configurations in Vagrantfile :

```
# Add more zones to CLUSTER_PRI_CONFIG or CLUSTER_DR_CONFIG
"rz2" => {
  "base_ip" => "192.168.56.20",
  "nodes" => [
    { "name" => "vault-pri-rz2-s1", "type" => "voting", "ip_offset" => 0 }
  ]
}
```
### Resource Adjustment
Modify the BOX_CONFIG section in Vagrantfile :

```
"vmware" => {
  "box" => "gyptazy/ubuntu22.04-arm64",
  "memory" => 4096,  # Increase memory
  "cpus" => 4        # Increase CPUs
}
```
## License
This project is for testing and educational purposes. Ensure you have proper Vault Enterprise licensing for production use.

## Contributing
Contributions are welcome! Please ensure:

- Test with multiple providers
- Update documentation for new features
- Follow existing code style
- Test DR scenarios thoroughly