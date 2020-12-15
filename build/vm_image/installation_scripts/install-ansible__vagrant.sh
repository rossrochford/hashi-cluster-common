#!/bin/bash

pip3 install --force-reinstall ansible==2.10.3 ansible-base==2.10.3

sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible=2.9.6+dfsg-1

sudo ansible-galaxy collection install community.general
