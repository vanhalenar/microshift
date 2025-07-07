FROM registry.redhat.io/rhel9-eus/rhel-9.6-bootc:9.6

ARG USHIFT_GIT_URL=https://github.com/vanhalenar/microshift.git
ARG USHIFT_BRANCH=amitest
ENV USER=microshift
ENV HOME=/microshift
ENV GOPATH=/microshift
ENV GOMODCACHE=/microshift/.cache

COPY ./bootc-images/microshift-crel.repo ./bootc-images/microshift-rhocp-y.repo \
    /etc/yum.repos.d/

RUN dnf install -y git 

RUN git clone --branch ${USHIFT_BRANCH} --single-branch ${USHIFT_GIT_URL} /microshift

# Adding non-root user for building microshift
RUN useradd -m -s /bin/bash microshift -d /microshift && \
    echo 'microshift  ALL=(ALL)  NOPASSWD: ALL' >/etc/sudoers.d/microshift && \
    chmod 0640 /etc/shadow


RUN chown -R microshift:microshift /microshift
USER microshift:microshift
WORKDIR /microshift

# Preparing for the build
RUN echo '{"auths":{"fake":{"auth":"aWQ6cGFzcwo="}}}' > /tmp/.pull-secret && \
    bash -x /microshift/scripts/devenv-builder/configure-vm-ami.sh /tmp/.pull-secret
