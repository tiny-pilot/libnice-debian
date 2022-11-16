# syntax=docker/dockerfile:1.4
# Enable here-documents:
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#here-documents

FROM debian:buster-20220418-slim AS build

RUN set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc \
    build-essential \
    dpkg-dev \
    git \
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
    ninja -C build install

ARG PKG_NAME="libnice10"
ARG PKG_BUILD_NUMBER="1"
ARG PKG_ARCH="armhf"
ARG PKG_ID="${PKG_NAME}_${PKG_VERSION}-${PKG_BUILD_NUMBER}_${PKG_ARCH}"
ARG PKG_DIR="/releases/${PKG_ID}"

RUN mkdir --parents "${PKG_DIR}"

# Copy headers to /usr/include.
RUN mkdir -p "${PKG_DIR}/usr/include" && \
    cp -R cp /usr/src/nice "${PKG_DIR}/usr/include/" && \
    cp -R cp /usr/src/stun "${PKG_DIR}/usr/include/"

# Copy compiled shared library into Debian package.
RUN cp \
    --parents \
    --no-dereference \
    /usr/lib/arm-linux-gnueabihf/libnice.so* "${PKG_DIR}/"

# Add copyright file.
RUN mkdir -p "${PKG_DIR}/usr/share/doc/${PKG_NAME}"
WORKDIR "${PKG_DIR}/usr/share/doc/${PKG_NAME}"
RUN cp /usr/src/libnice/COPYING copyright && \
    cp /usr/src/libnice/COPYING.LGPL . && \
    cp /usr/src/libnice/COPYING.MPL .

WORKDIR "${PKG_DIR}/DEBIAN"

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
