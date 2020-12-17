#!/bin/bash

mkdir -p /etc/consul.d
useradd --system --home /etc/consul.d --shell /bin/false consul

wget https://releases.hashicorp.com/consul/1.9.0/consul_1.9.0_linux_amd64.zip

unzip consul_1.9.0_linux_amd64.zip -d .
chown root:root consul
mv consul /usr/local/bin/consul
rm consul_1.9.0_linux_amd64.zip

mkdir -p /opt/consul/logs/
chown --recursive consul:consul /opt/consul

# docker pull envoyproxy/envoy:v1.16.0

# install CNI plugins
curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.9.0/cni-plugins-linux-amd64-v0.9.0.tgz
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins.tgz



# todo: these won't persist after restart, instead add a file to /etc/sysctl.d/  (https://www.nomadproject.io/docs/install/production/requirements#bridge-networking-and-iptables)
echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
