#!/bin/bash

VERSION=$1

if [ -f /usr/bin/envoy ]; then
    exit 0
fi

HOME_USER=$(echo $USER)

curl -L https://getenvoy.io/cli | sudo bash -s -- -b /usr/local/bin
sudo -u $HOME_USER getenvoy fetch "standard:$VERSION"

if [[ $HOME_USER == "root" ]]; then
  sudo cp "/root/.getenvoy/builds/standard/$VERSION/linux_glibc/bin/envoy" /usr/bin/envoy
else
  sudo cp "/home/$HOME_USER/.getenvoy/builds/standard/$VERSION/linux_glibc/bin/envoy" /usr/bin/envoy
fi

