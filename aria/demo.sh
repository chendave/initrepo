#!/bin/bash

set -e

mkdir demo
cd demo
sudo -H pip install virtualenv
virtualenv env
source env/bin/activate
# install ariatosca
pip install git+http://git-wip-us.apache.org/repos/asf/incubator-ariatosca.git
aria service-templates store examples/hello-world/helloworld.yaml my-service-template
# create service
aria services create my-service -t my-service-template
# workflow execution
aria executions start install -s my-service
# test it out, access it by http://localhost:9090/


# parse the template only
aria service-templates show hello -f

# for the cleanup...
aria executions start uninstall -s my-service
aria services delete hello-service -f
aria service-templates delete hello

# trouble shooting
# 1. this will show the detail message for the execution
aria logs list <execution_id> -vvv
# 2. those message are persisted in: ~/.aria/cli.log
# 3. you may see the error message like this:
# urllib2.URLError: <urlopen error [Errno 111] Connection refused>
# you may need check how is your /etc/hosts configured
# this is my
# 127.0.0.1       localhost openstack-dev openstack-dev.sh.intel.com
# 127.0.1.1       openstack-dev.sh.intel.com  openstack-dev
# 10.239.159.68   openstack-dev openstack-dev.sh.intel.com

# reference: https://github.com/apache/incubator-ariatosca
