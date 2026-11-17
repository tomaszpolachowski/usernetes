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
INFO "Created temporary directory at $tmpdir"
podman volume create $container-master
podman volume create $container-node
podman network create $container-network --driver bridge --subnet 10.100.0.0/16
podman run --rm --user 1000:1000 --network $container-network --ip 10.100.0.100 --name $container -v $container-master:/opt/usernetes/.config/usernetes/master -v $container-node:/opt/usernetes/.config/usernetes/nodes.$container --entrypoint /bin/bash $image -c "export XDG_RUNTIME_DIR='/opt/usernetes/run' && /usr/bin/mkdir -p /opt/usernetes/run && mkdir -p /opt/usernetes/run && /opt/usernetes/common/cfssl.sh --dir=/opt/usernetes/.config/usernetes --master=$container --node=$container,10.100.0.100"
podman run -dt --network $container-network --ip 10.100.0.100 --name $container --hostname $container -p 127.0.0.1:6443:6443 --tmpfs /tmp --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $container-master:/opt/usernetes/.config/usernetes/master -v $container-node:/opt/usernetes/.config/usernetes/node --privileged $image
function cleanup() {
	podman rm -f $container
	podman network rm $container-network
	podman volume rm $container-master
	podman volume rm $container-node
	rm -rf $tmpdir
	return
}
trap cleanup EXIT

if ! timeout 120 sh -exc "until [ \$(podman inspect -f '{{.State.Running}}' $container) = \"true\" ]; do sleep 10; done"; then
	podman logs $container
	exit 1
fi

podman cp $container:/opt/usernetes/.config/usernetes/master/admin.kubeconfig $tmpdir/admin.kubeconfig
sed -i s/$container:6443/127.0.0.1:6443/g $tmpdir/admin.kubeconfig
export KUBECONFIG=$tmpdir/admin.kubeconfig

mkdir -p $tmpdir/bin
podman cp $container:/opt/usernetes/bin/kubectl $tmpdir/bin/kubectl
chmod +x $tmpdir/bin/kubectl
export PATH=$tmpdir/bin:$PATH

INFO "Waiting for node to be ready."
if ! timeout -s INT -k 10 120 sh -exc "until [ \$(kubectl get nodes | grep \"Ready\" | grep -v \"NotReady\" | wc -l) = \"1\" ]; do sleep 10; done"; then
	ERROR "Node is not ready."
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	exit 1
fi

INFO "Waiting for pod to run."
if ! timeout -s TERM -k 10 60 time kubectl run --attach=true --rm --image busybox --restart=Never hello -- echo hello $container; then
	ERROR "Pod did not run successfully."
	kubectl get pods -o yaml
	kubectl get nodes -o yaml
	podman logs $container
	exit 1
fi

smoketest_dns
