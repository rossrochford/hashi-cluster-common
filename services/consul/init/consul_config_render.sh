#!/bin/bash

DO_SIGHUP=$1

cd /scripts/services/consul


# store config backups, this will help with debugging
if [[ $(check_exists "file" "/etc/consul.d/base.hcl") == "yes" ]]; then
  cp "/etc/consul.d/base.hcl" "/etc/consul.d/base.hcl.bak"
elif [[ $(check_exists "file" "/etc/consul.d/server.hcl") == "yes" ]]; then
  cp "/etc/consul.d/server.hcl" "/etc/consul.d/server.hcl.bak"
elif [[ $(check_exists "file" "/etc/consul.d/client.hcl") == "yes" ]]; then
  cp "/etc/consul.d/client.hcl" "/etc/consul.d/client.hcl.bak"
fi

export PYTHONPATH=/scripts/utilities
python3 /scripts/utilities/py_utilities/render_config_templates.py "consul"

consul-template -template "conf/agent/base.hcl.tmpl:/etc/consul.d/base.hcl" -once


if [[ "$NODE_TYPE" == "traefik" || "$NODE_TYPE" == "hashi_client" || "$NODE_TYPE" == "vault" ]]; then
  consul-template -template "conf/agent/client.hcl.tmpl:/etc/consul.d/client.hcl" -once
  if [[ "$DO_SIGHUP" == "true" ]]; then
    systemctl reload consul-client.service
  fi
elif [[ "$NODE_TYPE" == "hashi_server" ]]; then
  consul-template -template "conf/agent/server.hcl.tmpl:/etc/consul.d/server.hcl" -once
  if [[ "$DO_SIGHUP" == "true" ]]; then
    systemctl reload consul-server.service
  fi
fi
