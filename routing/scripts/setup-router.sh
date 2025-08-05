#!/bin/bash

set -e

echo "=== Setting up Ubuntu Router ==="

# Update system
# apt-get update

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Configure iptables for routing
echo "Setting up iptables rules..."

# Clear existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Allow forwarding between subnets
iptables -A FORWARD -i ens161 -o ens256 -j ACCEPT
iptables -A FORWARD -i ens256 -o ens161 -j ACCEPT

# Allow established and related connections
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow SSH (for management)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow ICMP (ping)
iptables -A INPUT -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT

# Create a simple script to restore rules on boot (optional)
cat > /etc/rc.local << 'EOF'
#!/bin/bash
# Restore iptables rules on boot
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -A FORWARD -i ens161 -o ens256 -j ACCEPT
iptables -A FORWARD -i ens256 -o ens161 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT
exit 0
EOF

chmod +x /etc/rc.local

echo "=== Ubuntu Router Setup Complete ==="
echo "Router VM is ready to route between 192.168.56.0/24 and 192.168.57.0/24"
echo "IP forwarding enabled and iptables rules configured"