#!/bin/bash
cd /home/demo/rm
bash start.sh
google-chrome &
# login MAAS dashboard with account admin admin
# MAAS dashboard IP address is 192.168.130.250:5240

# activate podm for maas
# collect inventory information from podm and written into databases;
cd /home/demo/RSD/podm
source env/bin/activate

# need to check the unit
python podm_maas3.py 300 &
# replace 23-30 to the start to end id that want to be deleted here
python podm_tool.py node delete 23-30

# clean any node that is with wrong status from MAAS dashboard

# refresh maas cache
maas refresh
# allocate 6 nodes for openstack deployments
python podm_tool.py node allocate "openstack-nodes" 6 CPU=2 MEM=10 HDD_SIZE=30 HDD_COUNT=1
# assemble nodes
python podm_tool.py node assemble 31-36
# create juju controller
juju bootstrap --show-log --debug --bootstrap-series=trusty maascloud maas-cloud-control --config=config.yaml

########################################################
# need bootstrap with this config to solve the issue
# about external network access
# cat config.yaml
# default-series: xenial
# no-proxy: localhost
# http-proxy: http://192.168.130.250:8000
# https-proxy: https://192.168.130.250:8000
# ftp-proxy: http://192.168.130.250:8000
########################################################


# start deploying
# check juju status
juju status
# add the five machines
juju add-machine -n 5
# depoly juju GUI
juju deploy --to 0 juju-gui

# show super user acount for the juju GUI
# and then login the JUJU GUI
juju show-controller --show-password
