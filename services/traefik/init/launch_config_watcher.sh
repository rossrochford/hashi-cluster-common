#!/bin/bash


AGENT_TOKEN=$(cat /tmp/ansible-data/traefik-shell-token.json | jq -r ".SecretID")

SERVICE_FP="/etc/systemd/system/watch-traefik-routes-updated.service"

cp /scripts/services/traefik/systemd/watch-traefik-routes-updated.service $SERVICE_FP

CONSUL_ADDR="127.0.0.1:8500"

sed -i "s|CONSUL_HTTP_ADDR=none|CONSUL_HTTP_ADDR=$CONSUL_ADDR|g" $SERVICE_FP
sed -i "s|CONSUL_HTTP_TOKEN=none|CONSUL_HTTP_TOKEN=$AGENT_TOKEN|g" $SERVICE_FP
sed -i "s|CTP_PREFIX=none|CTP_PREFIX=$CTP_PREFIX|g" $SERVICE_FP
sed -i "s|CTN_PREFIX=none|CTN_PREFIX=$CTN_PREFIX|g" $SERVICE_FP
sed -i "s|NODE_TYPE=none|NODE_TYPE=$NODE_TYPE|g" $SERVICE_FP
sed -i "s|HOSTING_ENV=none|HOSTING_ENV=$HOSTING_ENV|g" $SERVICE_FP


chmod 0644 "$SERVICE_FP"
systemctl daemon-reload

systemctl enable watch-traefik-routes-updated.service
systemctl start watch-traefik-routes-updated.service
