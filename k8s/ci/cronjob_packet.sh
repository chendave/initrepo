# this is on deployed on the packet

# crontab -e

SHELL=/bin/bash
#0 8 * * * cd /root/conformance-test && /bin/bash conformance-test.sh arm64-k8s-test  conformance-arm64 >> log.out
0 */12 * * * cd /root/conformance-test && ./conformance-test.sh arm64-k8s-test  conformance-arm64 >> log.out 2>&1
