#!/bin/bash
# These script show the commands to translate the TOSCA CSAR into HOT (Heat Orchestration Tempaltes)

# Get the CSAR from tosca parser project, the file may not been downloaded correclty, so
# you should verify the content manually.
wget https://github.com/openstack/tosca-parser/tree/master/toscaparser/tests/data/CSAR/csar_hello_world.zip
sudo pip install tosca-parser
sudo pip install heat-translator
# only convert the CSAR into HOT
heat-translator --template-file csar_hello_world.zip
# further more, deploy the stack
heat-translator --template-file csar_hello_world.zip --stack-name mystack --deploy
# The output may looks like the below
#heat_template_version: 2013-05-23
#
#description: >
#  Template for deploying a single server with predefined properties.
#
#parameters: {}
#resources:
#  my_server:
#    type: OS::Nova::Server
#    properties:
#      flavor: ds2G
#      user_data_format: SOFTWARE_CONFIG
#      image: rhel-6.5-test-image
#
#outputs: {}

# source openstack env
# check the stack is being running
openstack stack list


# Alternatively, docker can also do those jobs.
# Firtly, you should make sure the docker CE or ME is installed correclty.
# The template file must exist in "/tmp/tosca_testfiles" for the example.
#docker run -v /tmp/tosca_testfiles:/tosca patrocinio/h-t-container-stable --template-file /tosca/tosca_helloworld.yaml


# Reference:
# [1] https://developer.ibm.com/opentech/2016/11/08/package-cloud-workloads-tosca-cloud-service-archive/
# [2] https://github.com/openstack/heat-translator/blob/master/doc/source/usage.rst
# [3] https://developer.ibm.com/opentech/2017/04/10/docker-containerized-openstack-heat-translator/

