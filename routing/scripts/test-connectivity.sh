#!/bin/bash

echo "=== Testing Router Connectivity ==="

# Test from Subnet A to Subnet B
echo "Testing from Primary cluster (192.168.56.x) to DR cluster (192.168.57.x)..."
vagrant ssh vault-pri-rz1-s1 -c "ping -c 3 192.168.57.10" 2>/dev/null

# Test from Subnet B to Subnet A  
echo "Testing from DR cluster (192.168.57.x) to Primary cluster (192.168.56.x)..."
vagrant ssh vault-dr-rz1-s1 -c "ping -c 3 192.168.56.10" 2>/dev/null

# Test router accessibility
echo "Testing router accessibility..."
ping -c 3 192.168.56.1
ping -c 3 192.168.57.1

echo "=== Connectivity Test Complete ==="