#!/bin/bash
set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DNF_RETRY="${SCRIPTDIR}/../dnf_retry.sh"

start=$(date +%s)

function usage() {
    echo "Usage: $(basename "$0")  <openshift-pull-secret-file>"

    [ -n "$1" ] && echo -e "\nERROR: $1"
    exit 1
}

if [ $# -ne 1 ]; then
    usage "Wrong number of arguments"
fi

OCP_PULL_SECRET=$1
[ ! -e "${OCP_PULL_SECRET}" ] && usage "OpenShift pull secret file '${OCP_PULL_SECRET}' does not exist"
OCP_PULL_SECRET=$(realpath "${OCP_PULL_SECRET}")
[ ! -f "${OCP_PULL_SECRET}" ] && usage "OpenShift pull secret '${OCP_PULL_SECRET}' is not a regular file"

echo -e "${USER}\tALL=(ALL)\tNOPASSWD: ALL" | sudo tee "/etc/sudoers.d/${USER}"

"${DNF_RETRY}" "clean" "all"
"${DNF_RETRY}" "update"
"${DNF_RETRY}" "install" "gcc git golang cockpit make jq selinux-policy-devel rpm-build jq bash-completion avahi-tools createrepo"

# run only if booted with systemd
[[ -d /run/systemd/system ]] &&  sudo systemctl enable --now cockpit.socket

GO_VER=1.23.6
GO_ARCH=$([ "$(uname -m)" == "x86_64" ] && echo "amd64" || echo "arm64")
GO_INSTALL_DIR="/usr/local/go${GO_VER}"
if [ ! -d "${GO_INSTALL_DIR}" ] ; then
    echo "Installing go ${GO_VER}..."
    # This is installed into different location (/usr/local/bin/go) from dnf installed Go (/usr/bin/go) so it doesn't conflict
    # /usr/local/bin is before /usr/bin in $PATH so newer one is picked up
    curl -L -o "go${GO_VER}.linux-${GO_ARCH}.tar.gz" "https://go.dev/dl/go${GO_VER}.linux-${GO_ARCH}.tar.gz"
    sudo rm -rf "/usr/local/go${GO_VER}"
    sudo mkdir -p "/usr/local/go${GO_VER}"
    sudo tar -C "/usr/local/go${GO_VER}" -xzf "go${GO_VER}.linux-${GO_ARCH}.tar.gz" --strip-components 1
    sudo rm -rfv /usr/local/bin/{go,gofmt}
    sudo ln --symbolic /usr/local/go${GO_VER}/bin/{go,gofmt} /usr/local/bin/
    rm -rfv "go${GO_VER}.linux-${GO_ARCH}.tar.gz"
fi

"${DNF_RETRY}" "install" "openshift-clients"

# Configure OpenShift pull secret
if [ ! -e "/etc/crio/openshift-pull-secret" ]; then
    sudo mkdir -p /etc/crio/
    sudo cp -f "${OCP_PULL_SECRET}" /etc/crio/openshift-pull-secret
    sudo chmod 600 /etc/crio/openshift-pull-secret
fi

"${DNF_RETRY}" "install" "firewalld"
# sudo systemctl enable firewalld --now
# sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
# sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
# sudo firewall-cmd --permanent --zone=trusted --add-source=fd01::/48
# sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
# sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
# sudo firewall-cmd --permanent --zone=public --add-port=5353/udp
# sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp
# sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/udp
# sudo firewall-cmd --permanent --zone=public --add-port=6443/tcp
# sudo firewall-cmd --permanent --zone=public --add-service=mdns
# sudo firewall-cmd --reload

end="$(date +%s)"
duration_total_seconds=$((end - start))
duration_minutes=$((duration_total_seconds / 60))
duration_seconds=$((duration_total_seconds % 60))

echo ""
echo "Done in ${duration_minutes}m ${duration_seconds}s"
