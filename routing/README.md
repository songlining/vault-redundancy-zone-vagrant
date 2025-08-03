
# Routing
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│  Primary Cluster│    │    Router    │    │   DR Cluster    │
│  192.168.56.x   │◄──►│192.168.56.1  │◄──►│  192.168.57.x   │
│                 │    │192.168.57.1  │    │                 │
│ vault-pri-rz1-s1│    │ vault-router │    │ vault-dr-rz1-s1 │
│ vault-pri-rz1-s2│    │              │    │ vault-dr-rz1-s2 │
└─────────────────┘    └──────────────┘    └─────────────────┘
```

## Block with Iptables Rules
```shell
vagrant ssh router

# Block traffic from Subnet A to Subnet B
sudo iptables -I FORWARD 1 -s 192.168.56.0/24 -d 192.168.57.0/24 -j DROP

# Block traffic from Subnet B to Subnet A
sudo iptables -I FORWARD 2 -s 192.168.57.0/24 -d 192.168.56.0/24 -j DROP

# Verify rules are in place
sudo iptables -L FORWARD -n --line-numbers
```

## Remove Blocking Rules
```shell
# Remove the blocking rules (by line number)
sudo iptables -D FORWARD 1
sudo iptables -D FORWARD 1  # Line numbers shift after deletion

# Or flush all FORWARD rules and re-add allowing rules
sudo iptables -F FORWARD
sudo iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT
sudo iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
```