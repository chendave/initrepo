#!/bin/bash
# Use the default configuration provided here, you can
# create a vagrant guest with a valid private IP address
# and thus ssh to the guest and viceversa.
# sudo -E -H apt-get install -y virtualbox
wget --no-check-certificate https://releases.hashicorp.com/vagrant/1.8.7/vagrant_1.8.7_x86_64.deb
sudo dpkg -i vagrant_1.8.7_x86_64.deb
vagrant init
vagrant up
vagrant ssh control
# You can find the shared directory "/vagrant/" here
