#!/usr/bin/env bash

set -xeuo pipefail

sudo modprobe habanalabs && sudo modprobe habanalabs_cn && sudo modprobe habanalabs_ib && sudo modprobe habanalabs_en

oc create -f https://vault.habana.ai/artifactory/docker-k8s-device-plugin/habana-k8s-device-plugin.yaml
