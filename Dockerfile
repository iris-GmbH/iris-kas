# SPDX-License-Identifier: MIT
# Copyright (C) 2022 iris-GmbH infrared & intelligent sensors

FROM mikefarah/yq:4.33.2 AS yq

FROM ghcr.io/siemens/kas/kas:4.0
LABEL maintainer="Jasper Orschulko <Jasper.Orschulko@iris-sensing.com>"
USER root
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        cmake \
        icecc \
        awscli \
    && rm -rf /var/lib/apt/lists
COPY --from=yq /usr/bin/yq /usr/bin/yq
RUN yq --version
USER builder
