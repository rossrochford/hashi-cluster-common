#!/bin/bash

# based on: https://learn.hashicorp.com/tutorials/consul/dns-forwarding?in=consul/security-networking#systemd-resolved-setup
# and workaround for non-localhost IP: https://github.com/hashicorp/consul/issues/5985


{ echo ""; echo "[Resolve]"; echo "DNS=$NODE_IP"; echo "Domains=~consul"; } >> /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved


sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600

sudo iptables -t nat -A OUTPUT -p tcp -d "$NODE_IP" --dport 53 -j DNAT --to-destination "$NODE_IP:8600"
sudo iptables -t nat -A OUTPUT -p udp -d "$NODE_IP" --dport 53 -j DNAT --to-destination "$NODE_IP:8600"
sudo iptables -t nat -A PREROUTING -p tcp -d "$NODE_IP" --dport 53 -j DNAT --to-destination "$NODE_IP:8600"
sudo iptables -t nat -A PREROUTING -p udp -d "$NODE_IP" --dport 53 -j DNAT --to-destination "$NODE_IP:8600"
