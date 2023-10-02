# SPDX-License-Identifier: MIT
# Copyright (C) 2022 iris-GmbH infrared & intelligent sensors

# type can be set to ci. Override with "--build-arg type=ci" during build
ARG type=base
ARG REPO_REV=v2.37

FROM mikefarah/yq:4.30.6 AS yq

FROM alpine:3.17 AS git
ARG REPO_REV
RUN apk add --no-cache \
        git \
    && git clone --single-branch -b ${REPO_REV} https://android.googlesource.com/tools/repo /repo \
    && chmod +x /repo/repo

FROM ghcr.io/siemens/kas/kas:4.0 AS base
LABEL maintainer="Jasper Orschulko <Jasper.Orschulko@iris-sensing.com>"
USER root
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        cmake \
    && rm -rf /var/lib/apt/lists
COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY --from=git /repo/repo /usr/bin/repo
RUN ln -s /usr/bin/python3 /usr/bin/python \
    && repo --version \
    && yq --version

FROM base AS ci
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        icecc \
        awscli \
    && rm -rf /var/lib/apt/lists
USER builder

# This FROM statement will cause the build to either use the "base" or
# "ci" image layer as final image, depending on what the "type" argument is set to.
FROM ${type} AS final
ARG REPO_REV
ENV REPO_REV=${REPO_REV}
