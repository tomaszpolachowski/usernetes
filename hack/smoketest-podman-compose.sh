#!/bin/bash
source $(realpath $(dirname $0))/smoketest-common.inc.sh
cd $(realpath $(dirname $0)/..)
tmpdir=$(mktemp -d)
function cleanup() {
	set -x
	make down
	rm -rf $tmpdir
}
trap cleanup EXIT

INFO "Creating the cluster"
make _up
master="usernetes_master_1"
nodes="3"

export KUBECONFIG="$HOME/.config/usernetes/admin.kubeconfig"
podman cp $master:/opt/usernetes/bin/kubectl $tmpdir/kubectl
chmod +x $tmpdir/kubectl
export PATH=$tmpdir:$PATH

INFO "Waiting for master ($master) to be ready."
if ! timeout -s INT -k 10 60 sh -exc "until [ \$(podman inspect -f '{{.State.Running}}' $master) = \"true\" ]; do sleep 10; done"; then
	ERROR "Master is not running."
	set -x
	podman logs $master
	exit 1
fi

INFO "Waiting for $nodes nodes to be ready."
if ! timeout -s TERM -k 10 120 sh -exc "until [ \$(kubectl get nodes | grep \"Ready\" | grep -v \"NotReady\" | wc -l) = \"$nodes\" ]; do sleep 10; done"; then
	ERROR "Nodes are not ready."
	set -x
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	exit 1
fi
kubectl get nodes -o wide

app="nginx"
image="nginx:alpine"
INFO "Creating $app app"
kubectl create deployment $app --image=$image
kubectl scale deployment --replicas=$nodes $app
if ! timeout -s TERM -k 10 60 sh -exc "until [ \$(kubectl get pods -o json -l app=$app | jq -r \".items[].status.phase\" | grep -x \"Running\" | wc -l) = \"$nodes\" ]; do sleep 10; done"; then
	ERROR "Pods are not running."
	set -x
	kubectl get pods -o wide -l app=$app
	kubectl get pods -o yaml -l app=$app
	exit 1
fi
kubectl get pods -o wide
if ! [ $(kubectl get pods -o json -l app=$app | jq -r ".items[].spec.nodeName" | sort | uniq | wc -l) = "$nodes" ]; then
	ERROR "Pod replicas are not scaled across the nodes."
	set -x
	kubectl get pods -o wide -l app=$app
	kubectl get pods -o yaml -l app=$app
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	exit 1
fi

INFO "Creating the shell pod."
kubectl run --restart=Never --image=alpine shell sleep infinity
if ! timeout -s TERM -k 10 60 sh -exc 'until kubectl get pods -o json shell | jq -r ".status.phase" | grep -x "Running" ;do sleep 10; done'; then
	ERROR "The shell pod is not running."
	set -x
	kubectl get pods -o wide shell
	kubectl get pods -o yaml shell
	exit 1
fi
kubectl get pods -o wide

INFO "Connecting from the shell pod to the $app pods by IP."
for ip in $(kubectl get pods -o json -l app=$app | jq -r ".items[].status.podIP"); do
	INFO "Connecting to $ip."
	kubectl exec shell -- wget -O- $ip
done

smoketest_dns

INFO "PASS"
