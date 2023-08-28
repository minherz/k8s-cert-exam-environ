#!/usr/bin/env bash
# 
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# TODO: try these
#'https://dev.to/admantium/kubernetes-with-kubeadm-cluster-installation-from-scratch-51ae
#https://averagelinuxuser.com/kubernetes_containerd/
#https://devopsquare.com/how-to-create-kubernetes-cluster-with-containerd-90399ec3b810'

KUBELET_VERSION="1.27.1"; readonly KUBELET_VERSION

wait_startup_script_to_finish() {
    vm_name=$1
    vm_zone=$2
    echo -n "Wait for \"$vm_name\" startup script to exit."
    status=""
    while [[ -z "$status" ]]
    do
        sleep 3;
        echo -n "."
        status=$(gcloud compute ssh $vm_name --zone=$vm_zone --ssh-flag="-q" --command 'grep "startup-script exit status" /var/log/syslog' 2>&-) 
    done
    echo ""
}

PROJECT=$(gcloud config get-value project)
if [[ -z "$PROJECT" ]]
then
    echo "Please setup Project Id using 'gcloud config set project PROJECT_ID'"
    exit 1
fi

NETWORK="${1:-"default"}"; readonly NETWORK
SUBNET="${2:-"default"}"; readonly SUBNET
LOCATION=${LOCATION:="us-central1"}
ZONE=${ZONE:="$LOCATION-a"}

echo "🕸 Creating Kubernetes v21 cluster..."

# create control plane (master node)
# follow instructions to setup network config at
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic
# and create cluster with kubeadm at
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
gcloud compute instances create k8s-master --zone=$ZONE \
--machine-type=e2-medium \
--image=k8s-base-image \
--boot-disk-size=100GB \
--network="${NETWORK}" --subnet="${SUBNET}" \
--metadata startup-script="#! /bin/bash
if [[ -f /etc/initialized ]]; then exit 0; fi
truncate -s 0 /var/log/syslog
sudo modprobe br_netfilter
sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
cat > /etc/install.sh <<EOF
#! /bin/bash
KUBE_VERSION=${KUBELET_VERSION}
sudo kubeadm init --kubernetes-version=\${KUBE_VERSION} --ignore-preflight-errors=NumCPU --skip-token-print
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chmod go+rw ~/.kube/config
# Install WeaveWorks security AddOn
sudo kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
EOF
touch /etc/initialized"

wait_startup_script_to_finish k8s-master $ZONE

gcloud compute ssh k8s-master --zone=$ZONE --command='/bin/bash /etc/install.sh'
JOIN_CMD=$(gcloud compute ssh k8s-master --zone=$ZONE --command="sudo kubeadm token create --kubernetes-version=${KUBELET_VERSION} --print-join-command --ttl 0")

# create worker node
gcloud compute instances create k8s-node --zone=$ZONE \
--machine-type=e2-medium \
--image=k8s-base-image \
--boot-disk-size=100GB \
--network="${NETWORK}" --subnet="${SUBNET}" \
--metadata startup-script='#! /bin/bash
if [[ -f /etc/initialized ]]; then exit 0; fi
truncate -s 0 /var/log/syslog
sudo modprobe br_netfilter
sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
cat > /etc/install.sh <<EOF
#! /bin/bash
sudo systemctl daemon-reload
sudo service kubelet start
EOF
touch /etc/initialized'

wait_startup_script_to_finish k8s-node $ZONE

gcloud compute ssh k8s-node --zone=$ZONE --command='/bin/bash /etc/install.sh'
gcloud compute ssh k8s-node --zone=$ZONE --command="sudo $JOIN_CMD"


