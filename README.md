# Kubernetes Certification Exam Environment

> [!WARNING]
> The current version of the script is not stable.

All Linux Foundation Kubernetes certification exams use two node clusters with the most recent stable version of Kubernetes (now v20).
When learning toward certification exams it comes handy to be able to enroll new Kubernetes clusters that are similar to those used in the exam environment.
This project uses Google Compute Engine to provision VMs and then `kubeadm` to install the two node cluster.

## Prerequisites

To run the scripts one has to have a GCP project with a valid billing account attached to it and Cloud SDK installed on a workstation.

Also the Cloud SDK should be configured with the project id:

```bash
PROJECT_ID=<a_project_id>
gcloud config set project $PROJECT_ID
```

## Scripts

The repository has the following scripts:

### create_image.sh

When executed the script creates in the project a base image that is further used to provision a master and a worker Kubernetes nodes.
The image name will be `k8s-exam-base` and it will be set to the `ubuntu-os-cloud` image family.

> **Warning**
> Right now the script isn't idempotent.

### create_k8s_exam_cluster.sh

The script provisions a master (`k8s-master`) and a worker (`k8s-node`) Kubernetes nodes.
A location of the nodes can be defined by providing `LOCATION` environment with a value set to one of [GCP regions](https://cloud.google.com/compute/docs/regions-zones#available).
The VMs are always provisioned into `*-a` zone.

> **Warning**
> Make sure the following conditions are fulfilled:
>
> * `k8s-exam-base` image existence
> * availability of `*-a` zone in the provided region
> * uniqueness of the VM resource names

### k8s-base-image-startup.sh

`k8s-base-image-startup.sh` is auxiliary script that is used as a [startup script][1].
It is configured to launch as a part of the process of the base VM image creation.
`KUBE_VERSION` environment variable controls the version of Kubernetes to be used.
You may want to update its value if it does not suite your needs.
The startup script is too complex to integrate it into the script itself.
It was easier to define it as a stand-alone script instead of maintaining it in the body of the [create_image.sh](#create_image.sh).

[1]: https://cloud.google.com/compute/docs/instances/startup-scripts/linux#passing-local
