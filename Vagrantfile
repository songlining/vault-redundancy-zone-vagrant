# -*- mode: ruby -*-
# vi: set ft=ruby :

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Provider configuration - Set this to switch between providers
# Options: "virtualbox", "vmware", or "qemu"
PROVIDER = ENV['VAGRANT_PROVIDER'] || "vmware"  # Default to vmware

# Box configuration based on provider
# only vmware setting works for now
BOX_CONFIG = {
  "virtualbox" => {
    "box" => "bento/ubuntu-20.04",  # Official Ubuntu 22.04 ARM64 for VirtualBox
    "memory" => 3072,
    "cpus" => 2
  },
  "vmware" => {
    "box" => "gyptazy/ubuntu22.04-arm64",
    "memory" => 1024*2,
    "cpus" => 2
  },
  "qemu" => {
    "box" => "roboxes/ubuntu2204",  # Ubuntu 22.04 ARM64 for QEMU
    "memory" => "3G",  # QEMU uses string format
    "cpus" => 2
  }
}

# Primary cluster configuration (cluster-pri)
CLUSTER_PRI_CONFIG = {
  "cluster_name" => "cluster-pri",
  "zones" => {
    "rz1" => {
      "base_ip" => "192.168.56.10",
      "nodes" => [
        { "name" => "vault-pri-rz1-s1", "type" => "voting", "ip_offset" => 0 },
        { "name" => "vault-pri-rz1-s2", "type" => "nonvoting", "ip_offset" => 1 }
      ]
    },
    # "rz2" => {
    #   "base_ip" => "192.168.56.20",
    #   "nodes" => [
    #     { "name" => "vault-pri-rz2-voting", "type" => "voting", "ip_offset" => 0 }
    #   ]
    # },
    # "rz3" => {
    #   "base_ip" => "192.168.56.30",
    #   "nodes" => [
    #     { "name" => "vault-pri-rz3-voting", "type" => "voting", "ip_offset" => 0 }
    #   ]
    # }
  }
}

# Disaster Recovery cluster configuration (cluster-dr)
CLUSTER_DR_CONFIG = {
  "cluster_name" => "cluster-dr",
  "zones" => {
    "rz1" => {
      "base_ip" => "192.168.56.110",
      "nodes" => [
        { "name" => "vault-dr-rz1-s1", "type" => "voting", "ip_offset" => 0 },
        { "name" => "vault-dr-rz1-s2", "type" => "nonvoting", "ip_offset" => 1 }
      ]
    },
    # "rz2" => {
    #   "base_ip" => "192.168.56.120",
    #   "nodes" => [
    #     { "name" => "vault-dr-rz2-voting", "type" => "voting", "ip_offset" => 0 }
    #   ]
    # },
    # "rz3" => {
    #   "base_ip" => "192.168.56.130",
    #   "nodes" => [
    #     { "name" => "vault-dr-rz3-voting", "type" => "voting", "ip_offset" => 0 }
    #   ]
    # }
  }
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Helper function to calculate IP address
def calculate_ip(base_ip, offset)
  ip_parts = base_ip.split('.')
  ip_parts[3] = (ip_parts[3].to_i + offset).to_s
  ip_parts.join('.')
end

# Helper function to collect all cluster IPs
def collect_cluster_ips(cluster_config)
  ips = []
  cluster_config["zones"].each do |zone, config|
    config["nodes"].each do |node|
      ips << calculate_ip(config["base_ip"], node["ip_offset"])
    end
  end
  ips
end

# Helper function to find the last node for initialization
def find_last_node(cluster_config)
  last_zone = cluster_config["zones"].keys.last
  last_node = cluster_config["zones"][last_zone]["nodes"].last
  [last_zone, last_node]
end

# =============================================================================
# CLUSTER VARIABLES
# =============================================================================

# Collect all IPs for both clusters
PRI_CLUSTER_IPS = collect_cluster_ips(CLUSTER_PRI_CONFIG)
DR_CLUSTER_IPS = collect_cluster_ips(CLUSTER_DR_CONFIG)

# Find the last nodes for initialization
PRI_LAST_ZONE, PRI_LAST_NODE = find_last_node(CLUSTER_PRI_CONFIG)
DR_LAST_ZONE, DR_LAST_NODE = find_last_node(CLUSTER_DR_CONFIG)

# =============================================================================
# PROVIDER CONFIGURATIONS
# =============================================================================

# VMware provider configuration
def configure_vmware_provider(config)
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.memory = BOX_CONFIG[PROVIDER]["memory"]
    vmware.cpus = BOX_CONFIG[PROVIDER]["cpus"]
    vmware.gui = false
    vmware.vmx["ethernet0.virtualDev"] = "vmxnet3"
    vmware.vmx["tools.syncTime"] = "TRUE"
    vmware.vmx["time.synchronize.continue"] = "TRUE"
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    vmware.allowlist_verified = true
    vmware.vmx["ethernet0.startConnected"] = "TRUE"
    vmware.vmx["ethernet0.connectionType"] = "nat"
  end
end

# VirtualBox provider configuration
def configure_virtualbox_provider(config)
  config.vm.provider "virtualbox" do |vb|
    vb.memory = BOX_CONFIG[PROVIDER]["memory"]
    vb.cpus = BOX_CONFIG[PROVIDER]["cpus"]
    vb.gui = false
    
    # VirtualBox specific optimizations
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
    
    # Enable nested virtualization if supported
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
    
    # Optimize performance
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--pae", "on"]
  end
end

# QEMU provider configuration
def configure_qemu_provider(config)
  config.vm.provider "qemu" do |qe|
    qe.memory = BOX_CONFIG[PROVIDER]["memory"]
    qe.smp = BOX_CONFIG[PROVIDER]["cpus"]
    qe.arch = "aarch64"
    qe.machine = "virt,accel=hvf,highmem=off"
    qe.cpu = "cortex-a72"
    qe.net_device = "virtio-net-device"
    qe.drive_interface = "virtio"
    qe.ssh_port = "50022"
    qe.qemu_bin = "/opt/homebrew/bin/qemu-system-aarch64"
    qe.qemu_dir = "/opt/homebrew/share/qemu"
    
    # Use user-mode networking to avoid privilege requirements
    qe.extra_netdev_args = "restrict=off"
    qe.extra_qemu_args = [
      "-parallel", "null",
      "-monitor", "none",
      "-display", "none",
      "-vga", "none"
    ]
  end
end

# =============================================================================
# INITIALIZATION SCRIPTS
# =============================================================================

# Generic cluster initialization function (used for both PRI and DR)
def generate_cluster_initialization_script(all_ips, cluster_config)
  first_node_name = cluster_config["zones"].values.first['nodes'].first['name']
  cluster_name = cluster_config["cluster_name"]
  
  <<~SHELL
    echo "All #{cluster_name} nodes provisioned. Initializing Vault cluster..."
    
    # Wait for all Vault services to be ready
    echo "Waiting for all #{cluster_name} Vault nodes to be ready..."
    for ip in #{all_ips.join(' ')}; do
      echo "Checking $ip..."
      while ! curl -s http://$ip:8200/v1/sys/health >/dev/null 2>&1; do
        echo "Waiting for $ip to be ready..."
        sleep 5
      done
      echo "$ip is ready"
    done
    
    echo "All #{cluster_name} nodes ready. Running initialization..."
    
    # Run initialization script locally (this VM will connect to the first node)
    export VAULT_ADDR="http://#{all_ips.first}:8200"
    
    # Check if already initialized
    if ! vault status 2>/dev/null | grep -q "Initialized.*true"; then
      echo "Initializing #{cluster_name} Vault cluster..."
      vault operator init -key-shares=3 -key-threshold=2 -format=json > /vagrant/#{cluster_name}-init.json
      
      # Extract keys and token
      export UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vagrant/#{cluster_name}-init.json)
      export UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vagrant/#{cluster_name}-init.json)
      export UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' /vagrant/#{cluster_name}-init.json)
      export ROOT_TOKEN=$(jq -r '.root_token' /vagrant/#{cluster_name}-init.json)
      
      # Save root token
      echo "$ROOT_TOKEN" > /vagrant/#{cluster_name}-root-token.txt
      chmod 600 /vagrant/#{cluster_name}-root-token.txt
      
      echo "#{cluster_name} initialized successfully!"
    else
      echo "#{cluster_name} is already initialized."
      export ROOT_TOKEN=$(cat /vagrant/#{cluster_name}-root-token.txt 2>/dev/null || echo "")
    fi
    
    echo "Unsealing all #{cluster_name} nodes..."
    
    # First, unseal the leader node
    echo "Unsealing #{cluster_name} leader node (#{all_ips.first})..."
    export VAULT_ADDR="http://#{all_ips.first}:8200"
    vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/#{cluster_name}-init.json) 
    vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/#{cluster_name}-init.json) 
    echo "#{cluster_name} leader node unsealed successfully"
    
    # Wait for other nodes to join the cluster, then unseal them
    for ip in #{all_ips[1..-1].join(' ')}; do
      echo "Waiting for $ip to join #{cluster_name} cluster..."
      export VAULT_ADDR="http://$ip:8200"
      
      # Wait for node to be ready and joined
      while true; do
        if curl -s http://$ip:8200/v1/sys/health >/dev/null 2>&1; then
          # Check if node has joined the cluster by checking seal status
          seal_status=$(curl -s http://$ip:8200/v1/sys/seal-status 2>/dev/null || echo "{}")
          if echo "$seal_status" | jq -e '.initialized == true' >/dev/null 2>&1; then
            echo "$ip has joined the #{cluster_name} cluster"
            break
          fi
        fi
        echo "Waiting for $ip to join #{cluster_name} cluster..."
        sleep 5
      done
      
      # Add delay to ensure node is fully ready for unsealing
      echo "Waiting for $ip to stabilize after joining cluster..."
      sleep 15
      
      # Now unseal the node
      echo "Unsealing $ip..."
      if echo "$seal_status" | jq -e '.sealed == true' >/dev/null 2>&1; then
        vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/#{cluster_name}-init.json) 
        vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/#{cluster_name}-init.json) 
        echo "$ip unsealed successfully"
      else
        echo "$ip is already unsealed"
      fi
    done
    
    echo "\n=== #{cluster_name} Vault Cluster Ready ==="
    echo "Web UI: http://#{all_ips.first}:8200"
    echo "Root token: $(cat /vagrant/#{cluster_name}-root-token.txt)"
    echo "\nTo access #{cluster_name}:"
    echo "  vagrant ssh #{first_node_name}"
    echo "  export VAULT_ADDR=http://localhost:8200"
    echo "  export VAULT_TOKEN=$(cat /vagrant/#{cluster_name}-root-token.txt)"
    echo "  vault status"
    
    # Create cluster ready marker
    touch /vagrant/#{cluster_name}-ready
  SHELL
end

# DR configuration script (runs after both clusters are ready)
def generate_dr_configuration_script()
  <<~SHELL
    echo "=== Configuring DR Replication ==="
    
    # Wait for both clusters to be ready
    echo "Waiting for both clusters to be ready..."
    while [ ! -f "/vagrant/cluster-pri-ready" ] || [ ! -f "/vagrant/cluster-dr-ready" ]; do
      echo "Waiting for cluster initialization to complete..."
      sleep 10
    done
    
    echo "Both clusters are ready. Configuring DR replication..."
    
    # Step 3: Configure Primary cluster for DR
    echo "=== Step 3: Configuring Primary cluster as DR Primary ==="
    export VAULT_ADDR="http://#{PRI_CLUSTER_IPS.first}:8200"
    export VAULT_TOKEN=$(cat /vagrant/cluster-pri-root-token.txt)
    
    echo "Enabling DR replication on Primary cluster..."
    vault write -f sys/replication/dr/primary/enable
    
    # Generate secondary token for DR cluster
    echo "Generating DR secondary token..."
    vault write sys/replication/dr/primary/secondary-token id="cluster-dr" > /vagrant/dr-secondary-token.txt
    
    echo "Primary cluster configured as DR Primary"
    
    # Step 4: Configure DR cluster as DR Secondary
    echo "=== Step 4: Configuring DR cluster as DR Secondary ==="
    
    # Extract the secondary token
    SECONDARY_TOKEN=$(grep 'wrapping_token:' /vagrant/dr-secondary-token.txt | awk '{print $2}')
    
    if [ -z "$SECONDARY_TOKEN" ]; then
      echo "ERROR: Could not extract secondary token"
      exit 1
    fi
    
    # Configure DR cluster as secondary
    export VAULT_ADDR="http://#{DR_CLUSTER_IPS.first}:8200"
    export VAULT_TOKEN=$(cat /vagrant/cluster-dr-root-token.txt)
    
    echo "Converting DR cluster to DR Secondary..."
    
    # Check current replication status and demote if needed
    replication_status=$(vault read -format=json sys/replication/dr/status 2>/dev/null || echo '{}')
    current_mode=$(echo "$replication_status" | jq -r '.data.mode // "disabled"')
    
    if [ "$current_mode" = "primary" ] || [ "$current_mode" = "disabled" ]; then
      echo "DR cluster is currently $current_mode, demoting to prepare for DR secondary..."
      vault write -f sys/replication/dr/primary/demote 2>/dev/null || echo "Demotion completed or not needed"
      echo "Waiting for demotion to complete..."
      sleep 30
    fi
    
    echo "Enabling DR secondary replication..."
    if vault write sys/replication/dr/secondary/enable token="$SECONDARY_TOKEN" 2>/dev/null; then
      echo "DR secondary replication enabled successfully"
    else
      # Check if it's actually enabled despite the error
      sleep 10
      if vault read sys/replication/dr/status 2>/dev/null | grep -q "mode.*secondary"; then
        echo "DR secondary replication enabled successfully (some paths now disabled as expected)"
      else
        echo "Failed to enable DR secondary replication"
        exit 1
      fi
    fi
    
    # Wait for replication to sync
    echo "Waiting for DR replication to sync..."
    sleep 30

    # print out the DR status
    echo "DR Status:"
    vault read sys/replication/dr/status

    # the next step is to ssh to each DR nodes (except the leading node) to manually unseal them.
    
    echo "\n=== DR Configuration Complete ==="
    echo "Primary Cluster: http://#{PRI_CLUSTER_IPS.first}:8200 (DR Primary)"
    echo "DR Cluster: http://#{DR_CLUSTER_IPS.first}:8200 (DR Secondary)"
    echo "\nDR replication is now active between the clusters"
    echo "\nTo promote DR cluster in case of disaster:"
    echo "  vagrant ssh vault-dr-rz1-s1"
    echo "  export VAULT_ADDR=http://localhost:8200"
    echo "  vault write -f sys/replication/dr/secondary/promote"
  SHELL
end

# =============================================================================
# MAIN VAGRANT CONFIGURATION
# =============================================================================

Vagrant.configure("2") do |config|
  # Set box based on provider
  config.vm.box = BOX_CONFIG[PROVIDER]["box"]
  config.vm.box_check_update = false
  config.vm.boot_timeout = 600  # 10 minutes timeout
  
  # Add delays between VM starts (global)
  # config.vm.provision "shell", inline: "sleep 60", run: "always"
  
  # SSH configuration
  config.ssh.connect_timeout = 600  # Increase to 10 minutes
  config.ssh.insert_key = false
  config.ssh.forward_agent = true
  config.ssh.keep_alive = true
  
  # Configure providers
  configure_vmware_provider(config)
  configure_virtualbox_provider(config)
  configure_qemu_provider(config)

  # Create Primary Cluster VMs
  CLUSTER_PRI_CONFIG["zones"].each do |zone_name, zone_config|
    zone_config["nodes"].each do |node_config|
      config.vm.define node_config["name"] do |node|
        node.vm.hostname = node_config["name"]
        node_ip = calculate_ip(zone_config["base_ip"], node_config["ip_offset"])
        node.vm.network "private_network", ip: node_ip
        
        # Pass primary cluster IPs for retry_join
        retry_join_ips = PRI_CLUSTER_IPS.join(",")
        node.vm.provision "shell", path: "scripts/setup-node.sh", args: [zone_name, node_config["type"], CLUSTER_PRI_CONFIG["cluster_name"], retry_join_ips]
        
        # Add cluster initialization script to the last node of primary cluster
        if zone_name == PRI_LAST_ZONE && node_config == PRI_LAST_NODE
          node.vm.provision "shell", inline: generate_cluster_initialization_script(PRI_CLUSTER_IPS, CLUSTER_PRI_CONFIG)
        end
      end
    end
  end

  # Create DR Cluster VMs
  CLUSTER_DR_CONFIG["zones"].each do |zone_name, zone_config|
    zone_config["nodes"].each do |node_config|
      config.vm.define node_config["name"] do |node|
        node.vm.hostname = node_config["name"]
        node_ip = calculate_ip(zone_config["base_ip"], node_config["ip_offset"])
        node.vm.network "private_network", ip: node_ip
        
        # Pass DR cluster IPs for retry_join
        retry_join_ips = DR_CLUSTER_IPS.join(",")
        node.vm.provision "shell", path: "scripts/setup-node.sh", args: [zone_name, node_config["type"], CLUSTER_DR_CONFIG["cluster_name"], retry_join_ips]
        
        # Add cluster initialization script to the last node of DR cluster
        if zone_name == DR_LAST_ZONE && node_config == DR_LAST_NODE
          node.vm.provision "shell", inline: generate_cluster_initialization_script(DR_CLUSTER_IPS, CLUSTER_DR_CONFIG)
          
          # Add DR configuration script (runs after both clusters are ready)
          node.vm.provision "shell", inline: generate_dr_configuration_script()
        end
      end
    end
  end
end