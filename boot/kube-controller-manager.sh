#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export KUBECONFIG="$XDG_CONFIG_HOME/usernetes/master/kube-controller-manager.kubeconfig"

PROBES=30
while [[ PROBES -gt 0 ]] && ! kubectl --request-timeout='3s' get --raw='/readyz'; do
	sleep 1
	PROBES=$((PROBES-1))
done

if [[ PROBES -le 0 ]]; then
	echo 'Kubernetes API not ready'
	exit 1
fi

exec kube-controller-manager \
	--cluster-name=kubernetes \
	--cluster-signing-cert-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--cluster-signing-key-file=$XDG_CONFIG_HOME/usernetes/master/ca-key.pem \
	--kubeconfig=$XDG_CONFIG_HOME/usernetes/master/kube-controller-manager.kubeconfig \
	--root-ca-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--service-account-private-key-file=$XDG_CONFIG_HOME/usernetes/master/service-account-key.pem \
	--use-service-account-credentials=true \
	--allocate-node-cidrs=true \
	--cluster-cidr="10.5.0.0/16" \
	$@
