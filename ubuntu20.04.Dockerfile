FROM ubuntu:20.04 AS BASE

FROM BASE AS ENV_BOOTSTRAP

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /sources

ENV OS_VER=20.04

COPY ubuntu${OS_VER} \
     /sources/
RUN bash install-host-packages

# platform sdk tool wrapper scripts and templates
COPY backends/bash/deb-templates \
     /sources/deb-templates/
COPY backends/bash/packaging-tools \
     /sources/packaging-tools/
COPY backends/bash/sources \
     /sources/

ARG DEB_PATH
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT
ARG VAL_VERDE_GH_TEAM

ENV PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SOURCE_ROOT_BASE=${SOURCE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/sources} \
    STAGE_ROOT_BASE=${STAGE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/staging} \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM} \
    ANDROID_NDK_VERSION=r22 \
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
FROM ENV_BOOTSTRAP AS SOURCES_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-sources-builder

# gnu bootstrap build
FROM SOURCES_BUILDER AS GNU_BOOTSTRAP_BUILDER

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
FROM GNU_BOOTSTRAP_BUILDER AS PLATFORM_INDEPENDENT_PACKAGE_BUILDERS

# platform sdk package build scripts
COPY backends/bash/cross \
     backends/bash/gnu \
     /sources/

# gnu build
FROM PLATFORM_INDEPENDENT_PACKAGE_BUILDERS AS GNU_BUILDER

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu

# musl build
FROM GNU_BUILDER AS MUSL_BUILDER

COPY backends/bash/musl \
     /sources/

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=musl \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

RUN HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=musl \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

# android-ndk package
FROM MUSL_BUILDER AS ANDROID_NDK_BUILDER

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk

# webassembly build
FROM ANDROID_NDK_BUILDER AS WEBASSEMBLY_BUILDER

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
FROM WEBASSEMBLY_BUILDER AS ANDROID_BUILDER

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
FROM ANDROID_BUILDER AS WINDOWS_SOURCES_BUILDER

COPY backends/bash/windows \
     /sources/

# windows build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_BUILDER

RUN HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows

FROM WINDOWS_BUILDER AS RUST_BUILDER

COPY backends/bash/rust \
     /sources/

# rust build
RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-rust-build

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
