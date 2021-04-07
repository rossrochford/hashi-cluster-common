#!/bin/bash

sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
pip3 install ansible==3.2.0 --user
