#!/bin/bash

KEY=$1

PROJECT_INFO=$(cat $PROJECT_INFO_FILEPATH)

if [[ $KEY == "node_name" ]]; then
  echo $NODE_NAME
elif [[ $KEY == "node_type" ]]; then
  echo $NODE_TYPE
elif [[ $KEY == "node_ip" ]]; then
  echo $NODE_IP
elif [[ $KEY == "home_user" ]]; then
  if [[ $HOSTING_ENV == "vagrant" ]]; then
    echo "vagrant"
  elif [[ $HOSTING_ENV == "lxd" ]]; then
    echo "ubuntu"
  else
    echo $USER
  fi
elif [[ $KEY == "project_info" ]]; then
  echo $PROJECT_INFO
elif [[ $KEY == "cluster_service_project_id" ]]; then
  CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
  echo $CLUSTER_PROJECT_ID
elif [[ $KEY == "num_hashi_servers" ]]; then
  NUM_HASHI_SERVERS=$(echo "$PROJECT_INFO" | jq -r ".num_hashi_servers")
  echo "$NUM_HASHI_SERVERS"
fi
