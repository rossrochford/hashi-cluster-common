#!/bin/bash

# based on: https://learn.hashicorp.com/tutorials/consul/dns-forwarding?in=consul/security-networking#systemd-resolved-setup


# todo: should this be the bind address of the consul agent instead?
{ echo ""; echo "[Resolve]"; echo "DNS=127.0.0.1"; echo "Domains=~consul"; } >> /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved


sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
