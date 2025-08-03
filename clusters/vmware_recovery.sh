#!/bin/bash

# Stop all VMs
vmrun list | grep -v "Total running VMs" | while read vm; do
    [ -n "$vm" ] && vmrun stop "$vm" 2>/dev/null
done

# Kill VMware processes
sudo pkill -f vmware 2>/dev/null || true
sudo pkill -f vmrun 2>/dev/null || true
sudo killall "VMware Fusion" 2>/dev/null || true

# Clean up Vagrant
vagrant destroy -f
vagrant global-status --prune

# Remove and re-add box
vagrant box remove gyptazy/ubuntu24.04-beta-server-arm64 --force 2>/dev/null || true

# Clean lock files
find ~/.vagrant.d/boxes -name "*.lck" -delete 2>/dev/null || true
find ~/.vagrant.d/boxes -name "*.vmem" -delete 2>/dev/null || true

# Wait and restart VMware
sleep 5
open -a "VMware Fusion"

echo "Cleanup complete. You can now run 'vagrant up --no-parallel'"