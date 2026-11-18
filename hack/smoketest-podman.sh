#!/bin/bash
set -eu -o pipefail
source $(realpath $(dirname $0))/smoketest-common.inc.sh
if [[ $# -lt 2 ]]; then
	echo "Usage: $0 NAME IMAGE"
	exit 1
fi

cd $(realpath $(dirname $0)/..)
container=$1
image=$2

tmpdir=$(mktemp -d)
if [[ -n "${cri:-}" ]]; then
	cri="$cri"
else
	cri="podman"
fi

INFO "Created temporary directory at $tmpdir"
$cri volume create $container-master
$cri volume create $container-node
$cri network create $container-network --driver bridge --subnet 10.100.0.0/16
$cri run --rm --user 1000:1000 --network $container-network --ip 10.100.0.100 --name $container -v $container-master:/opt/usernetes/.config/usernetes/master -v $container-node:/opt/usernetes/.config/usernetes/nodes.$container --entrypoint /bin/bash $image -c "export XDG_RUNTIME_DIR='/opt/usernetes/run' && /usr/bin/mkdir -p /opt/usernetes/run && mkdir -p /opt/usernetes/run && /opt/usernetes/common/cfssl.sh --dir=/opt/usernetes/.config/usernetes --master=$container --node=$container,10.100.0.100"
$cri run -dt --network $container-network --ip 10.100.0.100 --name $container --hostname $container -p 127.0.0.1:6443:6443 --tmpfs /tmp --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $container-master:/opt/usernetes/.config/usernetes/master -v $container-node:/opt/usernetes/.config/usernetes/node --privileged $image
function cleanup() {
	$cri rm -f $container
	$cri network rm $container-network
	$cri volume rm $container-master
	$cri volume rm $container-node
	rm -rf $tmpdir
	return
}
trap cleanup EXIT

if ! timeout 120 sh -exc "until [ \$($cri inspect -f '{{.State.Running}}' $container) = \"true\" ]; do sleep 10; done"; then
	$cri logs $container
	exit 1
fi

$cri cp $container:/opt/usernetes/.config/usernetes/master/admin.kubeconfig $tmpdir/admin.kubeconfig
sed -i s/$container:6443/127.0.0.1:6443/g $tmpdir/admin.kubeconfig
export KUBECONFIG=$tmpdir/admin.kubeconfig

mkdir -p $tmpdir/bin
$cri cp $container:/opt/usernetes/bin/kubectl $tmpdir/bin/kubectl
chmod +x $tmpdir/bin/kubectl
export PATH=$tmpdir/bin:$PATH

INFO "Waiting for node to be ready."
if ! timeout -s INT -k 10 120 sh -exc "until [ \$(kubectl get nodes | grep \"Ready\" | grep -v \"NotReady\" | wc -l) = \"1\" ]; do sleep 10; done"; then
	ERROR "Node is not ready."
	$cri exec -t $container journalctl --output=short --no-pager -xe
	$cri exec -t $container systemctl status --no-pager
	$cri exec -t $container machinectl shell usernetes@ systemctl --user status --no-pager
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	exit 1
fi

INFO "Waiting for pod to run."
if ! timeout -s TERM -k 10 60 time kubectl run --attach=true --rm --image busybox --restart=Never hello -- echo hello $container; then
	ERROR "Pod did not run successfully."
	kubectl get pods -o yaml
	kubectl get nodes -o yaml
	$cri logs $container
	exit 1
fi

smoketest_dns
