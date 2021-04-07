#!/bin/bash


# copy utility scripts
cp /scripts/utilities/kv/ctn /usr/local/bin/ctn
cp /scripts/utilities/kv/ctp /usr/local/bin/ctp
cp /scripts/utilities/check_exists /usr/local/bin/check_exists
cp /scripts/utilities/go_discover /usr/local/bin/go_discover
cp /scripts/utilities/log_write /usr/local/bin/log_write
cp /scripts/utilities/metadata_get /usr/local/bin/metadata_get


export $(grep -v '^#' /etc/environment | xargs)


cd /scripts


python3 utilities/py_utilities/create_metadata.py

python3 utilities/py_utilities/render_config_templates.py "ansible"

mkdir -p /etc/ansible
mv "/scripts/build_$HOSTING_ENV/ansible/ansible.cfg" /etc/ansible/ansible.cfg


# setup Consul config and services
services/consul/init/vm_init.sh


mkdir -p /tmp/ansible-data/
chmod 0777 /tmp/ansible-data/


touch  /var/log/traefik-python-render.log
chmod 0777  /var/log/traefik-python-render.log


if [[ "$NODE_TYPE" == "vault" ]]
  then
    echo "CONSUL_HTTP_ADDR=\"127.0.0.1:8500\"" >> /etc/environment
    cp services/vault/init/vault_env.sh /etc/profile.d/vault_env.sh
else
  # these need to be set for the Consul and Nomad CLIs to work in ssh sessions
  echo "CONSUL_HTTP_ADDR=127.0.0.1:8500" >> /etc/environment
  #echo "CONSUL_HTTP_ADDR=\"$NODE_IP:8500\"" >> /etc/environment
  echo "NOMAD_ADDR=\"http://$NODE_IP:4646\"" >> /etc/environment  # todo: I think this can now be set to 127.0.0.1
fi

pip3 install docker==4.4.4 # todo: temp, this was moved to packer build


if [[ "$NODE_NAME" == "traefik-1" ]]; then
  # skipped if binary already exists
  build/vm_image/installation_scripts/install-envoy.sh 1.16.2
fi

if [[ "$NODE_NAME" == "hashi-server-1" ]]; then
  docker pull prom/prometheus:v2.26.0
fi

touch /scripts/common-end-reached.txt
