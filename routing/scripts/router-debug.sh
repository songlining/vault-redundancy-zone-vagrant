#!/bin/bash

echo "=== Router Debug Information ==="

vagrant ssh router -c "
  echo '=== System Info ==='
  uname -a
  
  echo '=== Network Interfaces ==='
  ip addr show
  
  echo '=== Routing Table ==='
  ip route show
  
  echo '=== IP Forwarding Status ==='
  cat /proc/sys/net/ipv4/ip_forward
  
  echo '=== Iptables Rules ==='
  sudo iptables -L -n -v
  
  echo '=== Network Statistics ==='
  cat /proc/net/dev
  
  echo '=== Active Connections ==='
  ss -tuln
"