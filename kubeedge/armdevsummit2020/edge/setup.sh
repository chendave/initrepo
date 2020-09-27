#!/bin/bash

mkdir /etc/kubeedge/config
~/kubeedge/edgecore --defaultconfig > /etc/kubeedge/config/edgecore.yaml

# TODO - update the config directly.
cp /root/devsummit/edgecore.yaml /etc/kubeedge/config/edgecore.yaml

#echo $token
#sed -i -e "s|token: .*|token: ${token}|g" edgecore.yaml

#nohup ./edgecore > edgecore.log 2>&1 &
