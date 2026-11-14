#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

# Configure backend db cluster for kubernetes
mkdir -p "$XDG_CONFIG_HOME/usernetes/etcd"
# Create env file with initial parameters for etcd cluster
cat <<EOF >"$XDG_CONFIG_HOME/usernetes/etcd/env"
ETCD_INITIAL_CLUSTER="$(while read n; do awk -F',' '{print $1"=https://"$2":2380";}' <<< "$n"; done <"$XDG_CONFIG_HOME/usernetes/master/nodes" | tr '\n' ',' | sed -e 's/,*$//g')"
ETCD_INITIAL_CLUSTER_TOKEN="$(<"$XDG_CONFIG_HOME/usernetes/master/token")"
ETCD_INITIAL_CLUSTER_STATE=new
export ETCD_INITIAL_CLUSTER ETCD_INITIAL_CLUSTER_TOKEN ETCD_INITIAL_CLUSTER_STATE
EOF
