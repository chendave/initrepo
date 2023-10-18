#!/bin/bash

. /etc/profile
. /root/.profile

RESULTS_DIR=${RESULTS_DIR:-"$(pwd)/k8s-e2e-results"}
LATEST_CI_VERSION=""
RUNONECE=${RUNONECE:-1}
PROJECT=${1}
JOB=${2}
ARCH=${ARCH:-"arm64"}
export GOROOT="/root/.gvm/gos/go1.20.5"
export PATH="${PATH}:/root/.gvm/pkgsets/go1.20.5/global/bin"

set -x

export KUBERNETES_CONFORMANCE_TEST='y'
export KUBECONFIG=""
export GINKGO_PARALLEL="y"
export GINKGO_PARALLEL_NODES="30"
export GINKGO_TOLERATE_FLAKES="n"

cd "$(dirname ${BASH_SOURCE[0]})"

if [[ $# != 2 ]]; then
	cat <<-EOF

	Welcome to the script that will run e2e tests and upload the test results on your behalf.

	Usage:
		${0} GCS_BUCKET JOB_SUITE

	Where
	- GCS_BUCKET points to a valid gs:// bucket that you own.
	- JOB_SUITE points to a subdirectory in GCS_BUCKET. That is: gs://${GCS_BUCKET}/logs/${JOB_SUITE}
	
	EOF
	exit 1
fi

main() {
	while true; do
		date
		echo ${PATH}
		#CI_VERSION=$(curl -sSL https://dl.k8s.io/release/latest.txt)
		export TMP_DIR=${RESULTS_DIR}/tmp/${CI_VERSION}
		#if [ -f latest_ci.txt ]; then
		#	LATEST_CI_VERSION=$(cat latest_ci.txt)
		#fi
		#if [[ ${LATEST_CI_VERSION} == ${CI_VERSION} ]]; then
		#	echo "No new updates to test, sleeping 3600 seconds and testing again"
		#	sleep 3600
		#	continue
		#fi
		#LATEST_CI_VERSION=${CI_VERSION}
		#cat > latest_ci.txt <<-EOF
		#	${LATEST_CI_VERSION}
		#	EOF
	
		# get Kubernetes source code of CI_VERSION
		# git clone https://github.com/kubernetes/kubernetes.git
		git --git-dir='kubernetes/.git' --work-tree='kubernetes' fetch
		git --git-dir='kubernetes/.git' --work-tree='kubernetes' checkout remotes/origin/master
		CI_VERSION=$(git --git-dir='kubernetes/.git' --work-tree='kubernetes' rev-parse --short HEAD)	
		LATEST_CI_VERSION=${CI_VERSION}


		echo "Using commit: ${CI_VERSION}"
		
		mkdir -p /mnt/k8s/e2e
		rm -rf /mnt/k8s/e2e/*
	
		NEWNUM=$(date +%s)
		echo "NEW number: ${NEWNUM}"
		mkdir -p ${RESULTS_DIR}/${JOB}
		mkdir -p ${RESULTS_DIR}/tmp/${CI_VERSION}
		echo ${NEWNUM} > ${RESULTS_DIR}/${JOB}/latest-build.txt
		sync

		JOB_DIR=${RESULTS_DIR}/${JOB}/${NEWNUM}
		mkdir -p ${JOB_DIR}/artifacts

		writeStartedJSON ${JOB_DIR} ${CI_VERSION}
		startTime=$(date +%s)
		echo "gsutil rsync -r ${RESULTS_DIR}/${JOB} gs://${PROJECT}/logs/${JOB}"
		# gsutil rsync -r ${RESULTS_DIR}/${JOB} gs://${PROJECT}/logs/${JOB}
		

		# write the kind config
		cat > kind-config.yaml <<-EOF
		# config for 1 control plane node and 2 workers (necessary for conformance)
		kind: Cluster
		apiVersion: kind.x-k8s.io/v1alpha4
		nodes:
		- role: control-plane
		- role: worker
		- role: worker
		EOF
				
		# build node-image for kind
		kind build node-image $(pwd)/kubernetes/  >>  ${JOB_DIR}/build-log.txt

		# create cluster
		kind create cluster --config kind-config.yaml --image kindest/node:latest >> ${JOB_DIR}/build-log.txt
		clusterUpTime=$(date +%s)

		# run conformance test
		cd kubernetes/
		make >> ${JOB_DIR}/build-log.txt
		cp _output/local/go/bin/kubectl ${TMP_DIR}/kubectl
		./hack/ginkgo-e2e.sh \
			'--provider=skeleton' \
			"--num-nodes=2" \
			"--ginkgo.focus=\\[Conformance\\]" \
			"--ginkgo.skip=\\[Serial\\]" \
			"--report-dir=/mnt/k8s/e2e" \
			>>  ${JOB_DIR}/build-log.txt
		cd ../
		passed="true"
		if [[ $(tail -1 ${JOB_DIR}/build-log.txt) == "FAIL" ]]; then
			passed="false"
		fi
		cp /mnt/k8s/e2e/junit_01.xml ${JOB_DIR}/artifacts/ -f

		writeNodesYAML ${JOB_DIR}
		doneTestingTime=$(date +%s)
		
		# delete cluster && code
		kind delete cluster >> ${JOB_DIR}/build-log.txt
		#rm -rf kubernetes

		writeMetadataJSON ${JOB_DIR} ${CI_VERSION}
		writeJunitRunnerXML ${JOB_DIR} ${passed} $((clusterUpTime-${startTime})) $((doneTestingTime-${clusterUpTime})) $((finishTime-${doneTestingTime}))
		writeFinishedJSON ${JOB_DIR} ${passed} ${CI_VERSION}

		# gsutil rsync -r ${RESULTS_DIR}/${JOB} gs://${PROJECT}/logs/${JOB}
		exit	

		if [[ ${RUNONCE} == 1 ]]; then
			exit
		fi
	done
}

writeStartedJSON(){
	echo "Writing started.json"
	cat > $1/started.json <<-EOF
	{
	    "version": "${2}",
	    "timestamp": $(date +%s),
	    "repos": {
	        "kubernetes/kubernetes": "${2}"
	    },
	    "repo-commit":"${2}",
	    "repo-version": "${2}"
	}
	EOF
}

writeMetadataJSON() {
	echo "Writing metadata.json"
	cat > $1/artifacts/metadata.json <<-EOF
	{"job-version":"${2}","version":"${2}"}
	EOF
}

writeNodesYAML() {
	echo "Writing nodes.yaml"
	${TMP_DIR}/kubectl get no -oyaml > $1/artifacts/nodes.yaml
}

writeJunitRunnerXML(){
	if [[ $2 == "true" ]]; then
		test_status="<testcase classname=\"e2e.go\" name=\"Test\" time=\"${4}\"/>"
		failures="0"
	else
		test_status="<testcase classname=\"e2e.go\" name=\"Test\" time=\"${4}\">
<failure>
An error occured when running e2e tests or all e2e tests did not pass
</failure>
</testcase>"
		failures="1"
	fi

	echo "Writing junit_runner.xml"
	cat > $1/artifacts/junit_runner.xml <<-EOF
	<testsuite failures="${failures}" tests="2" time="`expr ${3} + ${4}`">
	    <testcase classname="e2e.go" name="Up" time="${3}"/>
	    ${test_status}
	</testsuite>
	EOF
}

writeFinishedJSON(){
	echo "Writing finished.json"

	if [[ $2 == "true" ]]; then
		result="SUCCESS"
	else
		result="FAILED"
	fi

	cat > $1/finished.json <<-EOF
	{
	    "timestamp": $(date +%s),
	    "passed": ${2},
	    "metadata": {
	        "deployer-version":"${3}",
	        "kubetest-version":"${3}",
	        "tester-version":"${3}"
	    },
	    "result": "${result}",
	    "revision": "${3}"
	}
	EOF
}

main
