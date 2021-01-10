#!/bin/bash


mkdir -p /tmp/ansible-data/tls-certs-new
cd /tmp/ansible-data/tls-certs-new


# create the CA
consul tls ca create


SERVER_IP_ADDRESSES=$(go_discover consul-server "IP_HOSTNAME")


# create a certificate for each server
for IP_HOSTNAME in $SERVER_IP_ADDRESSES
do
  IP=$(echo $IP_HOSTNAME | cut -d"_" -f1)
  HOSTNAME=$(echo $IP_HOSTNAME | cut -d"_" -f2)
  consul tls cert create -server -additional-ipaddress=$IP
  mv dc1-server-consul-0-key.pem "dc1-server-consul-$HOSTNAME-key.pem"
  mv dc1-server-consul-0.pem "dc1-server-consul-$HOSTNAME.pem"
done


# create a certificate for the client agents (unlike the servers, the same one can be used by all clients)
CLIENT_IP_ADDRESSES=$(go_discover consul-client)
IP_ARGS=$(echo " $CLIENT_IP_ADDRESSES" | sed -e 's| | --additional-ipaddress=|g')

consul tls cert create -client $IP_ARGS

# zip files, lxd needs this as a file for fetch-consul-tls-certs.yml
zip /tmp/ansible-data/tls-certs-new.zip *
