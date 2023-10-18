rsync -av root@$IP_PACKET:/root/conformance-test/k8s-e2e-results/ /home/ruquan_zhao/k8s-e2e-results
gsutil rsync -r k8s-e2e-results/conformance-arm64 gs://arm64-k8s-test/logs/conformance-arm64
