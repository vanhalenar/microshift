#!/bin/bash
#
# This script should be run on the hypervisor to set up an nginx
# file-server for the images used by VMs running test scenarios.

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=test/bin/common.sh
source "${SCRIPTDIR}/common.sh"

usage() {
    cat - <<EOF
${BASH_SOURCE[0]} (start|stop)

  -h           Show this help.

start: Start the nginx web server. 

stop: Stop the nginx web server.

EOF
}

action_stop() {
    echo "Stopping web server"
    sudo pkill nginx || true
    exit 0
}

action_start() {
    echo "Starting web server in ${IMAGEDIR}"
    mkdir -p "${IMAGEDIR}"
    cd "${IMAGEDIR}"

    NGINX_CONFIG="${IMAGEDIR}/nginx.conf"
    # See the https://nginx.org/en/docs/http/ngx_http_core_module.html page for
    # a full list of HTTP configuration directives
    cat > "${NGINX_CONFIG}" <<EOF
worker_processes 32;
events {
}
http {
    access_log /dev/null;
    error_log  ${IMAGEDIR}/nginx_error.log;
    server {
        listen ${WEB_SERVER_PORT};
        listen [::]:${WEB_SERVER_PORT};
        root   ${IMAGEDIR};
        autoindex on;
    }

    # Timeout during which a keep-alive client connection will stay open on the server
    # Default: 75s
    keepalive_timeout 300s;

    # Timeout for transmitting a response to the client
    # Default: 60s
    send_timeout 300s;

    # Buffers used for reading response from a disk
    # Default: 2 32k
    output_buffers 2 1m;
}
pid ${IMAGEDIR}/nginx.pid;
daemon on;
EOF

    # Allow the current user to write to nginx temporary directories
    sudo chgrp -R "$(id -gn)" /var/lib/nginx

    # Kill running nginx processes and wait until down
    sudo pkill nginx || true
    while pidof nginx &>/dev/null ; do
        sleep 1
    done

    nginx \
        -c "${NGINX_CONFIG}" \
        -e "${IMAGEDIR}/nginx.log"
}

action_install() {
    mkdir -p "${IMAGEDIR}"
    
    SERVICE="${IMAGEDIR}/image_webserver.service"
    NGINX_CONFIG="${IMAGEDIR}/nginx.conf"
    SERVERSCRIPT="${IMAGEDIR}/image_webserver.sh"
    
    cat > "${SERVICE}" <<EOF
[Unit]
Description=Nginx file-server service for the images used by VMs running test scenarios.

[Service]
Type=simple
Restart=on-failure
RestartSec=1
User=microshift
ExecStart=/usr/bin/bash ${SERVERSCRIPT}

[Install]
WantedBy=multi-user.target
EOF

    cat > "${NGINX_CONFIG}" <<EOF
worker_processes 32;
events {
}
http {
    access_log /dev/null;
    error_log  ${IMAGEDIR}/nginx_error.log;
    server {
        listen ${WEB_SERVER_PORT};
        listen [::]:${WEB_SERVER_PORT};
        root   ${IMAGEDIR};
        autoindex on;
    }

    # Timeout during which a keep-alive client connection will stay open on the server
    # Default: 75s
    keepalive_timeout 300s;

    # Timeout for transmitting a response to the client
    # Default: 60s
    send_timeout 300s;

    # Buffers used for reading response from a disk
    # Default: 2 32k
    output_buffers 2 1m;
}
pid ${IMAGEDIR}/nginx.pid;
daemon off;
EOF

    cat > "${SERVERSCRIPT}" <<EOF
#!/bin/bash

nginx \
    -c "${NGINX_CONFIG}" \
    -e "${IMAGEDIR}/nginx.log"

EOF
    sudo chmod +x ${SERVERSCRIPT}
    sudo cp "${SERVICE}" /etc/systemd/system/image_webserver.service

    sudo systemctl start image_webserver.service
    sudo systemctl enable image_webserver.service

}

action_uninstall() {
    sudo systemctl stop image_webserver.service
    sudo systemctl disable image_webserver.service
    sudo rm /etc/systemd/system/image_webserver.service
    #sudo rm /etc/systemd/system/multi-user.target.wants/image_webserver.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi
action="${1}"
shift

case "${action}" in
    start|stop|install|uninstall)
        "action_${action}" "$@"
        ;;
    -h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac
