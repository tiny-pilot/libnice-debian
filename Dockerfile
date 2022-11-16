# syntax=docker/dockerfile:1.4
# Enable here-documents:
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#here-documents

FROM debian:buster-20220418-slim AS build

RUN set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    dpkg-dev \
    git \
    wget \
    python3-pip \
    cmake \
    pkg-config \
    libglib2.0-dev \
    libssl-dev \
    ninja-build

RUN pip3 install meson

ARG PKG_VERSION="0.0.0"

RUN mkdir -p "/usr/src/libnice"
WORKDIR "/usr/src/libnice"
RUN git clone https://gitlab.freedesktop.org/libnice/libnice \
        --branch "${PKG_VERSION}" \
        --single-branch \
        . && \
    meson --prefix=/usr build && \
    ninja -C build && \
    ninja -C build install && \
    pwd && \
    ls # DEBUG

# DEBUG
RUN pwd
RUN ls -l

ARG PKG_NAME="libnice10"
ARG PKG_BUILD_NUMBER="1"
ARG PKG_ARCH="armhf"
ARG PKG_ID="${PKG_NAME}_${PKG_VERSION}-${PKG_BUILD_NUMBER}_${PKG_ARCH}"
ARG PKG_DIR="/releases/${PKG_ID}"

RUN mkdir --parents "${PKG_DIR}"

# Copy compiled shared library into Debian package.
RUN cp --parents --no-dereference /usr/lib/arm-linux-gnueabihf/libnice.so* \
    "${PKG_DIR}/"

# Add copyright file.
WORKDIR "/releases/${PKG_ID}"
RUN mkdir -p "usr/share/doc/${PKG_NAME}"
COPY /usr/src/libnice/COPYING "usr/share/doc/${PKG_NAME}/copyright"
COPY /usr/src/libnice/COPYING.LGPL "usr/share/doc/${PKG_NAME}/COPYING.LGPL"
COPY /usr/src/libnice/COPYING.MPL "usr/share/doc/${PKG_NAME}/COPYING.MPL"

WORKDIR "${PKG_DIR}/debian"

RUN cat > control <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: devel
Priority: optional
Maintainer: TinyPilot Support <support@tinypilotkvm.com>
Depends: libssl1.1, libc6
Architecture: ${PKG_ARCH}
Homepage: https://libnice.freedesktop.org/
Description: An open source, general purpose, WebRTC server
EOF

RUN dpkg --build "${PKG_DIR}"

FROM scratch as artifact

COPY --from=build "/releases/*.deb" ./
