#!/bin/bash

set -e

# due to some reason from nodejs, it doesn't work on the ubuntu14.04, suggest
# to try it on the ubuntu16.04
sudo apt-get install nodejs
# npm is node js package management
sudo apt-get install npm
# for the well-known issue, install legacy will add a link between node and nodejs
sudo apt-get install nodejs-legacy
# since npm doesn't hornor system proxy, we need set the proxy specified for npm.
npm config set proxy http://proxyhost:proxyport
# note: it's http not https for the https_proxy
npm config set https-proxy http://proxyhost:proxyport

# download the source and setup the swagger edit.
git clone https://github.com/swagger-api/swagger-editor.git
cd swagger-editor
npm start
# wait couple of mins

# expected result is:
# Starting up http-server, serving ...
# http://10.239.48.39:3001
