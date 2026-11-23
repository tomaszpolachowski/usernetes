#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export KUBECONFIG="$XDG_CONFIG_HOME/usernetes/master/admin.kubeconfig"

kubeapi::api_ready || exit 1

exec kubectl apply \
  -f ${U7S_BASE_DIR}/manifests/kube-subnet-mgr.yaml \
  -f ${U7S_BASE_DIR}/manifests/kube-network-policies.yaml \
  -f ${U7S_BASE_DIR}/manifests/apiserver-kubelet-admin.yaml \
  -f ${U7S_BASE_DIR}/manifests/coredns.yaml
