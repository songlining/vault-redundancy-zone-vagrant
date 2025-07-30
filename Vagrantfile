# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "gyptazy/ubuntu22.04-arm64"
  config.vm.box_check_update = false
  config.vm.boot_timeout = 600  # 10 minutes timeout
  
  # SSH configuration
  config.ssh.connect_timeout = 600  # Increase to 10 minutes
  config.ssh.insert_key = false
  config.ssh.forward_agent = true
  config.ssh.keep_alive = true
  
  # Shared configuration for all VMs
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.memory = 2048
    vmware.cpus = 2
    vmware.gui = false
    vmware.vmx["ethernet0.virtualDev"] = "vmxnet3"
    vmware.vmx["tools.syncTime"] = "TRUE"
    vmware.vmx["time.synchronize.continue"] = "TRUE"
    # Add this line to fix the networking issue
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    # Additional networking fixes
    vmware.allowlist_verified = true
    # Add retry logic for network issues
    vmware.vmx["ethernet0.startConnected"] = "TRUE"
    vmware.vmx["ethernet0.connectionType"] = "nat"
    # Increase memory if VMs are hanging due to resource constraints
    vmware.memory = 2048  # Already set
  end

  # Redundancy Zone 1
  config.vm.define "vault-rz1-voting" do |node|
    node.vm.hostname = "vault-rz1-voting"
    node.vm.network "private_network", ip: "192.168.56.10"
    node.vm.provision "shell", path: "scripts/setup-node.sh", args: ["rz1", "voting"]
  end

  config.vm.define "vault-rz1-nonvoting" do |node|
    node.vm.hostname = "vault-rz1-nonvoting"
    node.vm.network "private_network", ip: "192.168.56.11"
    node.vm.provision "shell", path: "scripts/setup-node.sh", args: ["rz1", "nonvoting"]
  end

  # Redundancy Zone 2
  config.vm.define "vault-rz2-voting" do |node|
    node.vm.hostname = "vault-rz2-voting"
    node.vm.network "private_network", ip: "192.168.56.20"
    node.vm.provision "shell", path: "scripts/setup-node.sh", args: ["rz2", "voting"]
  end

  # Redundancy Zone 3
  config.vm.define "vault-rz3-voting" do |node|
    node.vm.hostname = "vault-rz3-voting"
    node.vm.network "private_network", ip: "192.168.56.30"
    node.vm.provision "shell", path: "scripts/setup-node.sh", args: ["rz3", "voting"]
    
    # Initialize cluster after all nodes are provisioned
    node.vm.provision "shell", inline: <<-SHELL
      echo "All nodes provisioned. Initializing Vault cluster..."
      
      # Wait for all Vault services to be ready
      echo "Waiting for all Vault nodes to be ready..."
      for ip in 192.168.56.10 192.168.56.11 192.168.56.20 192.168.56.30; do
        echo "Checking $ip..."
        while ! curl -s http://$ip:8200/v1/sys/health >/dev/null 2>&1; do
          echo "Waiting for $ip to be ready..."
          sleep 5
        done
        echo "$ip is ready"
      done
      
      echo "All nodes ready. Running initialization..."
      
      # Run initialization script locally (this VM will connect to the first node)
      export VAULT_ADDR="http://192.168.56.10:8200"
      
      # Check if already initialized
      if ! vault status 2>/dev/null | grep -q "Initialized.*true"; then
        echo "Initializing Vault cluster..."
        vault operator init -key-shares=3 -key-threshold=2 -format=json > /vagrant/init.json
        
        # Extract keys and token
        export UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vagrant/init.json)
        export UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vagrant/init.json)
        export UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' /vagrant/init.json)
        export ROOT_TOKEN=$(jq -r '.root_token' /vagrant/init.json)
        
        # Save root token
        echo "$ROOT_TOKEN" > /vagrant/root-token.txt
        chmod 600 /vagrant/root-token.txt
        
        echo "Vault initialized successfully!"
      else
        echo "Vault is already initialized."
        export ROOT_TOKEN=$(cat /vagrant/root-token.txt 2>/dev/null || echo "")
      fi
      
      echo "Unsealing all nodes..."
      
      # First, unseal the leader node
      echo "Unsealing leader node (192.168.56.10)..."
      export VAULT_ADDR="http://192.168.56.10:8200"
      vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/init.json) 
      vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/init.json) 
      echo "Leader node unsealed successfully"
      
      # Wait for other nodes to join the cluster, then unseal them
      for ip in 192.168.56.11 192.168.56.20 192.168.56.30; do
        echo "Waiting for $ip to join cluster..."
        export VAULT_ADDR="http://$ip:8200"
        
        # Wait for node to be ready and joined
        while true; do
          if curl -s http://$ip:8200/v1/sys/health >/dev/null 2>&1; then
            # Check if node has joined the cluster by checking seal status
            seal_status=$(curl -s http://$ip:8200/v1/sys/seal-status 2>/dev/null || echo "{}")
            if echo "$seal_status" | jq -e '.initialized == true' >/dev/null 2>&1; then
              echo "$ip has joined the cluster"
              break
            fi
          fi
          echo "Waiting for $ip to join cluster..."
          sleep 5
        done
        
        # Now unseal the node
        echo "Unsealing $ip..."
        if echo "$seal_status" | jq -e '.sealed == true' >/dev/null 2>&1; then
          vault operator unseal $(jq -r '.unseal_keys_b64[0]' /vagrant/init.json) 
          vault operator unseal $(jq -r '.unseal_keys_b64[1]' /vagrant/init.json) 
          echo "$ip unsealed successfully"
        else
          echo "$ip is already unsealed"
        fi
      done
      
      echo "\n=== Vault Cluster Ready ==="
      echo "Web UI: http://192.168.56.10:8200"
      echo "Root token: $(cat /vagrant/root-token.txt)"
      echo "\nTo access Vault:"
      echo "  vagrant ssh vault-rz1-voting"
      echo "  export VAULT_ADDR=http://localhost:8200"
      echo "  export VAULT_TOKEN=$(cat /vagrant/root-token.txt)"
      echo "  vault status"
    SHELL
  end
end