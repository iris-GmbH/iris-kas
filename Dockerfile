# SPDX-License-Identifier: MIT
# Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

# TYPE can be set to jenkins. Override with "--build-arg type=jenkins" during build
ARG type=base

FROM golang:1.17 as builder
ENV YQ_VERSION=v4.13.3
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        git \
        ca-certificates \
    && git clone --single-branch -b ${YQ_VERSION} https://github.com/mikefarah/yq.git /yq \
    && cd /yq \
    && CGO_ENABLED=0 go build .

FROM ghcr.io/siemens/kas/kas:next as base
LABEL maintainer="Jasper Orschulko <Jasper.Orschulko@iris-sensing.com>"
COPY --from=builder /yq/yq /usr/local/bin/yq

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
