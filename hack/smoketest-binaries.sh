#!/bin/bash
source $(realpath $(dirname $0))/smoketest-common.inc.sh
cd $(realpath $(dirname $0)/..)
function cleanup() {
	journalctl --user -xe --no-pager
	$(pwd)/show-status.sh
	$(pwd)/uninstall.sh || true
	eval $($(pwd)/show-cleanup-command.sh) || true
}
trap cleanup EXIT

set -x
./install.sh

export KUBECONFIG=$HOME/.config/usernetes/master/admin.kubeconfig
export PATH=$(pwd)/bin:$PATH

if ! timeout -s TERM -k 10 60 sh -exc 'until [ $(kubectl get nodes | grep "Ready" | grep -v "NotReady" | wc -l) = "1" ]; do sleep 10; done'; then
	ERROR "Node is not ready."
	set -x
	set +eu
	systemctl --user status u7s-kube-apiserver
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	exit 1
fi

kubectl get nodes -o wide
kubectl get pods -o wide

INFO "FIXME: remove this sleep"
sleep 10

if ! timeout -s TERM -k 10 60 kubectl run --attach=true --rm --image busybox --restart=Never hello -- echo hello; then
	ERROR "Pod is not ready."
	set -x
	set +eu
	kubectl get pods -o yaml
	kubectl get nodes -o yaml
	exit 1
fi

smoketest_dns

smoketest_limits
