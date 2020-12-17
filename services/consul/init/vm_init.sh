#!/bin/bash


# todo: move installation lines into packer script
# todo: include license, attribution and modification notices: https://github.com/hashicorp/terraform-aws-consul/blob/master/LICENSE
sudo /scripts/services/system-misc/systemd-resolved/configure_consul_dns_forwarding.sh
#sudo /scripts/services/system-misc/systemd-resolved/setup-systemd-resolved.sh --consul-ip "$NODE_IP"
#sudo systemctl restart systemd-resolved.service


# render consul config files
python3 /scripts/utilities/py_utilities/render_config_templates.py "consul"


chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/*.hcl


if [[ "$NODE_TYPE" == "traefik" || "$NODE_TYPE" == "hashi_client" || "$NODE_TYPE" == "vault" ]]; then
  cp /scripts/services/consul/systemd/consul-client.service /etc/systemd/system/consul-client.service
elif [[ "$NODE_TYPE" == "hashi_server" ]]; then
  cp /scripts/services/consul/systemd/consul-server.service /etc/systemd/system/consul-server.service
fi

sudo systemctl daemon-reload


# testing DNS:
# dig @127.0.0.1 -p 8600 consul.service.consul SRV
