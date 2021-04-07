#!/bin/bash


mkdir -p /etc/nomad.d 
chmod -R 0777 /etc/nomad.d   # grant read/write to all users, todo: this is too permissive, documentation suggests chmod 700

mkdir -p /opt/nomad/logs/
chmod -R 0777 /opt/nomad

wget https://releases.hashicorp.com/nomad/1.0.4/nomad_1.0.4_linux_amd64.zip
unzip nomad_1.0.4_linux_amd64.zip
chown root:root nomad
mv nomad /usr/local/bin/nomad
rm nomad_1.0.4_linux_amd64.zip
