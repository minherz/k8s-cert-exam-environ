#! /bin/bash
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

echo "--- Setting up working environment..."
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc

echo "--- Switching to root"
sudo -i

KUBELET_VERSION="1.27.1"; readonly KUBELET_VERSION

echo "--- Installing prerequisites"
apt-get update
# set apt-get upgrade to restart _all_ services instead of going interactive mode
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
apt-get upgrade -y
apt-get install -y bash-completion binutils apt-transport-https ca-certificates curl

echo "Disabling swapping..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Installing containerd CRI"
apt-get install -y containerd

echo "Installing Kubernetes..."
# instructions are taken from https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# in releases older than Ubuntu 22.04, /etc/apt/keyrings does not exist by default.
mkdir -p /etc/apt/keyrings
chmod 755 /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=${KUBELET_VERSION}-00 kubeadm=${KUBELET_VERSION}-00 kubectl=${KUBELET_VERSION}-00
apt-mark hold kubelet kubeadm kubectl

# start kubelet
systemctl enable kubelet
systemctl start kubelet

kubeadm reset -f
