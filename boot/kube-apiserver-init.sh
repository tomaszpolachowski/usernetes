#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export KUBECONFIG="$XDG_CONFIG_HOME/usernetes/master/admin.kubeconfig"

PROBES=30
while [[ PROBES -gt 0 ]] && ! kubectl --request-timeout='3s' get --raw='/readyz'; do
	sleep 1
	PROBES=$((PROBES-1))
done

if [[ PROBES -le 0 ]]; then
	echo 'Kubernetes API not ready'
	exit 1
fi

exec kubectl apply \
  -f ${U7S_BASE_DIR}/manifests/kube-subnet-mgr.yaml \
  -f ${U7S_BASE_DIR}/manifests/kube-network-policies.yaml \
  -f ${U7S_BASE_DIR}/manifests/apiserver-kubelet-admin.yaml \
  -f ${U7S_BASE_DIR}/manifests/coredns.yaml
