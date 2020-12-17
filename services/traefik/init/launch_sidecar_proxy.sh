#!/bin/bash

TOKEN_FP="/etc/traefik/traefik-consul-service-token.json"
SERVICE_FP="/etc/systemd/system/traefik-sidecar-proxy.service"

if [[ $(check_exists "file" $TOKEN_FP) == "no" ]]; then
  consul acl token create -description="traefik-up service token" -service-identity="traefik-up" -format=json > $TOKEN_FP
fi


# only needs rendering once per node, the only template variables are node-ip and the token, it doesn't need re-rendering when Traefik routes are updated
if [[ $(check_exists "file" $SERVICE_FP) == "no" ]]; then

  TOKEN=$(cat $TOKEN_FP | jq -r ".SecretID")

  consul-template -template "/scripts/services/traefik/systemd/traefik-sidecar-proxy.service.tmpl:$SERVICE_FP" -once
  sed -i "s|CONSUL_HTTP_TOKEN=none|CONSUL_HTTP_TOKEN=$TOKEN|g" $SERVICE_FP

  chmod 0644 $SERVICE_FP
  systemctl daemon-reload
fi


systemctl enable traefik-sidecar-proxy.service
systemctl start traefik-sidecar-proxy.service