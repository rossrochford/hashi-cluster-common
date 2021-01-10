#!/bin/bash


NODE_IP=$(metadata_get node_ip)
export ANSIBLE_REMOTE_USER=$USER
# export CLUSTER_PROJECT_ID=$(metadata_get cluster_service_project_id)  todo: remove this line

NOMAD_VAULT_TOKENS_FILEPATH="/tmp/ansible-data/nomad-vault-tokens.json"


run_playbook () {
  # assumed to run from dir: /scripts/build/ansible
  if [[ $HOSTING_ENV == "vagrant" || $HOSTING_ENV == "lxd" ]]; then
    ansible-playbook --limit "all:!localhost" "playbooks/init/$1/$2"
  else
    ansible-playbook -i ./auth.gcp.yml "playbooks/init/$1/$2" \
      --extra-vars="ansible_ssh_private_key_file=/etc/collected-keys/sa-ssh-key"
  fi

  if [[ $? != 0 ]]; then
    log_write "critical" "playbook $1/$2 failed, exiting bootstrap_cluster_services.sh"; exit 1
  fi
}


# set gossip encryption key
# ------------------------------
export GOSSIP_ENCRYPTION_KEY=$(consul keygen)

run_playbook consul set-gossip-encryption-key.yml



# Create and distribute TLS certificates
# ----------------------------------------
run_playbook consul create-tls-certs.yml  # sudo /scripts/services/consul/init/create_tls_certs.sh

run_playbook consul place-tls-certs.yml



# start Consul servers, wait server agents to join and discover each other
# -----------------------------------------------------------------

run_playbook prometheus start-prometheus-container.yml
run_playbook consul start-server-agents.yml

run_playbook consul wait-for-leader-election.yml
sleep 12  # sometimes Consul isn't yet ready, wait 12s



# Bootstrap Consul ACL
# -----------------------------------------------------------------

export CONSUL_HTTP_ADDR="http://127.0.0.1:8500"

run_playbook consul acl-init.yml  #/scripts/services/consul/init/consul_acl_init.sh

if [[ $? != 0 ]]; then
  echo "consul acl-init.yml failed, exiting"; exit 1
fi


CONSUL_UI_TOKEN_RW=$(cat /tmp/ansible-data/consul-ui-token-rw.json | jq -r ".SecretID")
CONSUL_UI_TOKEN_RO=$(cat /tmp/ansible-data/consul-ui-token-ro.json | jq -r ".SecretID")
export CONSUL_BOOTSTRAP_TOKEN=$(cat /tmp/ansible-data/consul-bootstrap-token.json | jq -r ".SecretID")
export CONSUL_HTTP_TOKEN=$CONSUL_BOOTSTRAP_TOKEN



# set Consul server & client agent tokens, start client agents
# ----------------------------------------------------

run_playbook consul set-server-agent-tokens.yml; sleep 5

run_playbook consul set-client-agent-tokens.yml

run_playbook consul start-client-agents.yml; sleep 2

# after ACL bootstrapping is complete, configure the anonymous token policy
run_playbook consul configure-anonymous-token  #/scripts/services/consul/init/configure_anonymous_token.sh



# Register nodes with Consul KV  - used by consul-template on Vault and Nomad config files
# -----------------------------------------

sleep 15
run_playbook consul register-nodes-with-consul-kv.yml



# Initialize Vault
# ---------------------
export VAULT_IP_ADDRS=$(go_discover vault-server)

if [[ $(check_exists "env" "VAULT_IP_ADDRS") == "no" ]]; then echo "error: no vault servers found by go_discover"; exit 1; fi

export VAULT_IP_ADDR_1=$(echo $VAULT_IP_ADDRS | cut -d' ' -f1)


run_playbook vault initialize-vault.yml


if [[ $(check_exists "file" $NOMAD_VAULT_TOKENS_FILEPATH) == "no" ]]; then echo "error: missing nomad-vault-tokens.json"; exit 1; fi
export NOMAD_VAULT_TOKENS=$(cat $NOMAD_VAULT_TOKENS_FILEPATH)



# Initialize Nomad
# ----------------------

run_playbook nomad initialize-nomad.yml



# Add read-only tokens to /etc/environment on each node, with a special token for hashi-server-1
# --------------------------------------------

echo "setting agent tokens for shell"
run_playbook consul set-agent-tokens-for-shell.yml



# Initialize Traefik (note: set-agent-tokens-for-shell.yml should preceed this because traefik/init/launch_config_watcher.sh uses the consul agent token)
# ------------------------------

run_playbook traefik initialize-traefik.yml



# create zip file of tokens
# ---------------------------------
# PASSWORD=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)
# zip --password $PASSWORD -r /tmp/ansible-data.zip /tmp/ansible-data > /dev/null



# print out tokens
# ----------------------------------

VAULT_ROOT_TOKEN=$(cat /tmp/ansible-data/vault-root-token.txt)
VAULT_WRITEONLY_TOKEN=$(cat /tmp/ansible-data/vault-writeonly-token.txt)
VAULT_UNSEAL_KEY=$(cat /tmp/ansible-data/vault-unseal-key.txt)


echo "-----------------------------------------------------------"

echo ""
echo "consul bootstrap token:                         $CONSUL_BOOTSTRAP_TOKEN"
echo "consul gossip encryption key:                   $GOSSIP_ENCRYPTION_KEY"

echo ""
echo "consul UI token (read/write):                   $CONSUL_UI_TOKEN_RW"
echo "consul UI token (read-only):                    $CONSUL_UI_TOKEN_RO"

echo ""
echo "vault root token:                               $VAULT_ROOT_TOKEN"
echo "vault write-only token:                         $VAULT_WRITEONLY_TOKEN"

if [[ $VAULT_UNSEAL_KEY != "none" ]]; then
  echo "vault unseal key:                               $VAULT_UNSEAL_KEY"
fi
