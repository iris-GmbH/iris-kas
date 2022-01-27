# SPDX-License-Identifier: MIT
# Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

# type can be set to jenkins. Override with "--build-arg type=jenkins" during build
ARG type=base

ARG KAS_VER=2.6.1
ARG REPO_REV=v2.17.2
ARG YQ_REV=v4.13.5

FROM golang:1.17 as builder
ARG REPO_REV
ARG YQ_REV
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        git \
        ca-certificates \
    && git clone --single-branch -b ${YQ_REV} https://github.com/mikefarah/yq.git /yq \
    && cd /yq \
    && CGO_ENABLED=0 go build . \
    && git clone --single-branch -b ${REPO_REV} https://android.googlesource.com/tools/repo /repo \
    && chmod +x /repo/repo

FROM ghcr.io/siemens/kas/kas:${KAS_VER} as base
LABEL maintainer="Jasper Orschulko <Jasper.Orschulko@iris-sensing.com>"
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        cmake \
    && rm -rf /var/lib/apt/lists
COPY --from=builder /yq/yq /usr/bin/yq
COPY --from=builder /repo/repo /usr/bin/repo

FROM base as jenkins
# Jenkins (and some other CI systems) override the entrypoint.
# As a result, a non-privileged user needs to be added manually.
RUN set -ex \
    && adduser --gecos '' --uid=1000 --disabled-password builder
ENTRYPOINT []
VOLUME /var/lib/docker
USER builder

# This FROM statement will cause the build to either use the "base" or
# "jenkins" image layer as final image, depending on what the "type" argument is set to.
FROM ${type} as final
ARG REPO_REV
ENV REPO_REV=${REPO_REV}
