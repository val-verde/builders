FROM ubuntu:20.04 AS ubuntu

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /sources

ENV OS_VER=20.04

COPY ubuntu${OS_VER} \
     /sources/
RUN bash install-host-packages

ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT
ARG VAL_VERDE_GH_TEAM

ENV PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SOURCE_ROOT_BASE=${SOURCE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/sources} \
    STAGE_ROOT_BASE=${STAGE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/staging} \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM} \
    ANDROID_NDK_VERSION=r22b \
    BUILD_DEB_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/build-debs \
    SOURCE_DEB_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/source-debs

ENV BUILD_ARCH=skylake \
    BUILD_CPU=skylake \
    BUILD_KERNEL=linux \
    BUILD_OS=gnu \
    BUILD_OS_API_LEVEL= \
    BUILD_PROCESSOR=x86_64

RUN mkdir -p ${BUILD_DEB_PATH} ${SOURCE_DEB_PATH}

# platform sdk tool wrapper scripts and templates
COPY backends/bash/deb-templates \
     /sources/deb-templates/
COPY backends/bash/packaging-tools \
     /sources/packaging-tools/

COPY /source-debs/ \
     ${SOURCE_DEB_PATH}

# upstream source package build
FROM ubuntu AS sources_builder

COPY backends/bash/sources \
     /sources/

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-sources-builder

# gnu bootstrap build
FROM sources_builder AS gnu_bootstrap_builder

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

# platform sdk bootstrap package build scripts
COPY backends/bash/compiler-tools/bin/* \
     /usr/bin/
COPY backends/bash/compiler-tools/libexec/* \
     /usr/libexec/
COPY backends/bash/bootstrap \
     /sources/

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap

# platform independent package builders
FROM gnu_bootstrap_builder AS platform_independent_package_builders

# platform sdk package build scripts
COPY backends/bash/cross \
     backends/bash/gnu \
     /sources/

# gnu build
FROM platform_independent_package_builders AS gnu_builder

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu

# macos build
FROM gnu_builder AS macos_builder

COPY backends/bash/darwin \
     /sources/

RUN DARWIN_OS=darwin \
    DARWIN_OS_API_LEVEL=20 \
    HOST_ARCH=haswell \
    HOST_CPU=haswell \
    HOST_KERNEL=apple \
    HOST_OS=macos \
    HOST_OS_API_LEVEL=11 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-darwin

RUN DARWIN_OS=darwin \
    DARWIN_OS_API_LEVEL=20 \
    HOST_ARCH=armv8-a \
    HOST_CPU=apple-a14 \
    HOST_KERNEL=apple \
    HOST_OS=macos \
    HOST_OS_API_LEVEL=11 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-darwin

# musl build
FROM macos_builder AS musl_builder

COPY backends/bash/musl \
     /sources/

RUN HOST_ARCH=broadwell \
    HOST_CPU=broadwell \
    HOST_KERNEL=linux \
    HOST_OS=musl \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

RUN HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=musl \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

# webassembly build
FROM musl_builder AS webassembly_builder

COPY backends/bash/webassembly \
     /sources/

RUN HOST_ARCH=wasm32 \
    HOST_CPU=wasm32 \
    HOST_KERNEL=unknown \
    HOST_OS=wasi \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=wasm32 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-webassembly

# android build
FROM webassembly_builder AS android_builder

# android package builders
COPY backends/bash/android \
     /sources/

# android-aarch64 environment
RUN HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# android-x86_64 environment
RUN HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# windows environment
FROM android_builder AS windows_sources_builder

COPY backends/bash/windows \
     /sources/

# windows build
FROM windows_sources_builder AS windows_builder

RUN HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows

FROM windows_builder AS rust_builder

COPY backends/bash/rust \
     /sources/

# rust build
RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-rust-build

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
