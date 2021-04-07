#!/bin/bash


GOSSIP_KEY=$1

if [[ $(check_exists "file" "/etc/consul.d/base.hcl") == "yes" ]]; then
sed -i "s|__GOSSIP_ENCRYPTION_KEY__|$GOSSIP_KEY|g" /etc/consul.d/base.hcl
fi

# also replace in template file so the key isn't lost if re-rendered later
sed -i "s|__GOSSIP_ENCRYPTION_KEY__|$GOSSIP_KEY|g"  /scripts/services/consul/conf/agent/base.hcl.tmpl
