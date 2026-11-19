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
	systemctl --user status
	kubectl get nodes -o wide
	ip a
	ip r
	exit 1
fi

kubectl get nodes -o wide

INFO "FIXME: remove this sleep"
sleep 10

# kubectl get pods -A -o wide
# kubectl get deployments -A -o wide
# kubectl describe deployment -n kube-system coredns
# systemctl --user status --no-pager
# systemctl --user status u7s-kube-controller-manager.service
# systemctl --user status u7s-kube-scheduler.service
# kubectl get pods -n kube-system | cut -f1 -d' ' | tail -n +2 | xargs -I{} kubectl describe pod -n kube-system {}
# cat /etc/hosts
# cat /etc/resolv.conf
# ./boot/nsenter.sh cat /etc/hosts
# ./boot/nsenter.sh cat /etc/resolv.conf
# ./boot/nsenter.sh ip a
# ./boot/nsenter.sh ip r
# curl --max-time 5s -i http://google.com
# nslookup google.com
# ./boot/nsenter.sh nslookup google.com
# ./boot/nsenter.sh curl --max-time 5s -i http://google.com

if ! timeout -s TERM -k 10 60 kubectl run --attach=true --rm --image busybox --restart=Never hello -- echo hello; then
	ERROR "Pod is not ready."
	set -x
	set +eu
	systemctl --user status
	kubectl get pods -o wide
	kubectl get nodes -o wide
	ip a
	ip r
	exit 1
fi

smoketest_dns

smoketest_limits
