# SPDX-License-Identifier: MIT
# Copyright (C) 2022 iris-GmbH infrared & intelligent sensors

# type can be set to ci. Override with "--build-arg type=ci" during build
ARG type=base

FROM mikefarah/yq:4.33.2 AS yq

FROM ghcr.io/siemens/kas/kas:4.0 AS base
LABEL maintainer="Jasper Orschulko <Jasper.Orschulko@iris-sensing.com>"
USER root
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        cmake \
    && rm -rf /var/lib/apt/lists
COPY --from=yq /usr/bin/yq /usr/bin/yq
RUN yq --version

FROM base AS ci
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        icecc \
        awscli \
    && rm -rf /var/lib/apt/lists

# This FROM statement will cause the build to either use the "base" or
# "ci" image layer as final image, depending on what the "type" argument is set to.
FROM ${type} AS final
USER builder
