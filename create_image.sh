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

PROJECT="$(gcloud config get project)"
if [[ -z "$PROJECT" ]]
then
    echo "Please setup Project Id using 'gcloud config set project PROJECT_ID'"
    exit 1
fi

NETWORK="${1:-default}"
SUBNET="${2:-default}"
LOCATION=${LOCATION:-"us-central1"}
ZONE=${ZONE:-"$LOCATION-a"}
VM_NAME=cks-node-image
echo "🖼 Creating VM image..."
gcloud compute instances create $VM_NAME --zone="$ZONE" \
--machine-type=e2-medium \
--image=ubuntu-1804-bionic-v20230510 \
--image-project=ubuntu-os-cloud \
--boot-disk-size=50GB \
--scopes=https://www.googleapis.com/auth/cloud-platform \
--metadata-from-file startup-script=./k8s-base-image-startup.sh \
--network="$NETWORK" --subnet="$SUBNET"

wait_startup_script_to_finish $VM_NAME $ZONE

# create custom image
gcloud compute instances stop $VM_NAME --zone=$ZONE
gcloud compute images create k8s-exam-base \
--source-disk=$VM_NAME \
--source-disk-zone=$ZONE \
--family=ubuntu-os-cloud \
--storage-location=$LOCATION
