#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export KUBECONFIG="$XDG_CONFIG_HOME/usernetes/master/kube-scheduler.kubeconfig"

kubeapi::api_ready || exit 1

exec kube-scheduler \
	--kubeconfig=$XDG_CONFIG_HOME/usernetes/master/kube-scheduler.kubeconfig \
	$@
