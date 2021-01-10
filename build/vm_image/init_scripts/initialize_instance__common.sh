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
  echo "NOMAD_ADDR=\"http://$NODE_IP:4646\"" >> /etc/environment
fi


if [[ "$NODE_NAME" == "traefik-1" ]]; then
  # install envoy (todo: move to packer) (todo: also pull prometheus image in packer)
  HOME_USER=$(metadata_get home_user)
  curl -L https://getenvoy.io/cli | sudo bash -s -- -b /usr/local/bin
  sudo -u $HOME_USER getenvoy fetch standard:1.16.1
  sudo cp "/home/$HOME_USER/.getenvoy/builds/standard/1.16.1/linux_glibc/bin/envoy" /usr/bin/envoy
fi


touch /scripts/common-end-reached.txt
