#!/usr/bin/env bash

set -xeuo pipefail

### DRIVER

# https://docs.habana.ai/en/latest/Installation_Guide/Driver_Installation.html

wget -nv https://vault.habana.ai/artifactory/gaudi-installer/1.20.1/habanalabs-installer.sh
chmod +x habanalabs-installer.sh
./habanalabs-installer.sh install --type base

sudo dnf install -y habanalabs-container-runtime

sudo dnf install -y habanalabs-qual-workloads

habanalabs-installer.sh install -t deps -y -v

sudo dnf install -y ethtool # we might not need this, not sure

