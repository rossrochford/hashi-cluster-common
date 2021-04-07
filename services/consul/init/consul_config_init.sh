#!/bin/bash

# start temporary consul -dev agent and populate with initial data so templates can be rendered
# -----------------------------------
mkdir -p /tmp/ansible-data/consul-dev-agent-data  # may not be necessary because -dev agents have persistence disabled
chown --recursive consul:consul /tmp/ansible-data/consul-dev-agent-data

cp /scripts/services/consul/systemd/consul-agent-dev.service /etc/systemd/system/consul-agent-dev.service
sudo systemctl daemon-reload
systemctl enable consul-agent-dev.service
systemctl start consul-agent-dev.service
sleep 5


# set kv data before rendering config templates
# ----------------------------------------------
# note: this is being run on every node against a -dev agent to aid config rendering, this KV data will be cleared
# when the -dev agent is shut down. hashi-server-1 re-runs this once the real consul cluster comes online
python3 /scripts/utilities/py_utilities/consul_kv.py initialize-project-metadata
consul kv put "$CTP_PREFIX/consul-config/acl-enabled" "false"
consul kv put "$CTP_PREFIX/consul-config/acl-default-policy" "allow"
consul kv put "$CTP_PREFIX/consul-config/tls-enabled" "false"
python3 /scripts/utilities/py_utilities/consul_kv.py register-node

# ----------------------------------------------


/scripts/services/consul/init/consul_config_render.sh "false"

systemctl stop consul-agent-dev.service