ARG OS_RELEASE_VERSION=${OS_RELEASE_VERSION}
FROM fedora:${OS_RELEASE_VERSION} AS fedora

WORKDIR /sources

COPY fedora \
     /sources/
RUN bash install-host-packages

ARG PACKAGE_ARCHIVE_CLASS
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT
ARG VAL_VERDE_GH_TEAM

ENV PACKAGE_ARCHIVE_CLASS=${PACKAGE_ARCHIVE_CLASS} \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SOURCE_ROOT_BASE=${SOURCE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/sources} \
    STAGE_ROOT_BASE=${STAGE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/staging} \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM} \
    ANDROID_NDK_VERSION=r25 \
    RELEASE_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/release-archives \
    CUDA_VERSION=11.7.1 \
    MACOS_VERSION=12 \
    PYTHON_VERSION=3.10 \
    SOURCE_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/source-archives \
    BOOTSTRAP_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/bootstrap-archives

ENV BUILD_ARCH=westmere \
    BUILD_CPU=westmere \
    BUILD_KERNEL=linux \
    BUILD_OS=gnu \
    BUILD_OS_API_LEVEL= \
    BUILD_PROCESSOR=x86_64

RUN mkdir -p ${RELEASE_ARCHIVE_PATH} \
             ${SOURCE_ARCHIVE_PATH} \
             ${BOOTSTRAP_ARCHIVE_PATH}

# platform sdk tool wrapper scripts and templates
COPY backends/bash/archive-templates \
     /sources/archive-templates/
COPY backends/bash/packaging-tools \
     /sources/packaging-tools/

# upstream source package build
FROM fedora AS sources_builder

COPY /source-archives/ \
     ${SOURCE_ARCHIVE_PATH}
COPY backends/bash/sources \
     /sources/

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-sources-builder

COPY /bootstrap-archives/ \
     ${BOOTSTRAP_ARCHIVE_PATH}

# bootstrap binaries build
FROM sources_builder AS binaries_builder

# platform sdk bootstrap package build scripts
RUN mkdir -p ${SOURCE_ROOT_BASE}/compiler-tools-0
COPY backends/bash/compiler-tools \
     ${SOURCE_ROOT_BASE}/compiler-tools-0/
COPY backends/bash/compiler-tools/libexec/* \
     /usr/libexec/
COPY backends/bash/bootstrap \
     /sources/

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-binaries-builder

# gnu bootstrap build
FROM binaries_builder AS gnu_bootstrap_builder

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap

ENV BUILD_SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_CPU}/sysroot/usr/glibc-interface

COPY /release-archives/ \
     ${RELEASE_ARCHIVE_PATH}

# platform sdk package build scripts
COPY backends/bash/cross \
     /sources/

# system base build
FROM gnu_bootstrap_builder AS system_base_builder

ENV ENABLE_32_BIT_BUILD=

# windows system base package builders
COPY backends/bash/windows-base \
     /sources/

# windows-x86_64 environment
RUN HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=w64 \
    HOST_OS=mingw \
    HOST_OS_API_LEVEL=64 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows-base

# windows-i786 environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=prescott \
        HOST_CPU=westmere \
        HOST_KERNEL=w64 \
        HOST_OS=mingw \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=i786 \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows-base; \
    fi

# windows-aarch64 environment
RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=w64 \
    HOST_OS=mingw \
    HOST_OS_API_LEVEL=64 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows-base

# windows-armv7a environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=armv7-a+fp \
        HOST_CPU=apple-m1 \
        HOST_KERNEL=w64 \
        HOST_OS=mingw \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=armv7a \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows-base; \
    fi

# webassembly system base package builders
COPY backends/bash/webassembly \
     /sources/

RUN HOST_ARCH=wasm32 \
    HOST_CPU=wasm32 \
    HOST_KERNEL=unknown \
    HOST_OS=wasi \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=wasm32 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-webassembly

# gnu build
FROM system_base_builder AS gnu_builder

# gnu package builders
COPY backends/bash/gnu \
     /sources/

# gnu build environment
RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu

# gnu-aarch64 environment
RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-binaries-builder

RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap

RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu

# gnu-i786 environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=prescott \
        HOST_CPU=westmere \
        HOST_KERNEL=linux \
        HOST_OS=gnu \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=i786 \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap; \
    fi

RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=prescott \
        HOST_CPU=westmere \
        HOST_KERNEL=linux \
        HOST_OS=gnu \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=i786 \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu; \
    fi

# gnueabihf-armv7a environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=armv7-a+fp \
        HOST_CPU=apple-m1 \
        HOST_KERNEL=linux \
        HOST_OS=gnu \
        HOST_OS_API_LEVEL=eabihf \
        HOST_PROCESSOR=armv7a \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap; \
    fi

RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=armv7-a+fp \
        HOST_CPU=apple-m1 \
        HOST_KERNEL=linux \
        HOST_OS=gnu \
        HOST_OS_API_LEVEL=eabihf \
        HOST_PROCESSOR=armv7a \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu; \
    fi

# macos build
FROM gnu_builder AS macos_builder

# macos package builders
COPY backends/bash/darwin \
     /sources/

RUN DARWIN_OS=darwin \
    DARWIN_OS_API_LEVEL=21 \
    HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=apple \
    HOST_OS=macos \
    HOST_OS_API_LEVEL=${MACOS_VERSION} \
    HOST_PROCESSOR=x86_64 \
    SYSROOT=${SOURCE_ROOT_BASE}/macosx-${MACOS_VERSION} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt-builder

# macos-x86_64 environment
RUN DARWIN_OS=darwin \
    DARWIN_OS_API_LEVEL=21 \
    HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=apple \
    HOST_OS=macos \
    HOST_OS_API_LEVEL=${MACOS_VERSION} \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-darwin

# macos-aarch64 environment
RUN DARWIN_OS=darwin \
    DARWIN_OS_API_LEVEL=21 \
    HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=apple \
    HOST_OS=macos \
    HOST_OS_API_LEVEL=${MACOS_VERSION} \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-darwin

# musl build
FROM macos_builder AS musl_builder

# musl package builders
COPY backends/bash/musl \
     /sources/

# musl-x86_64 environment
RUN HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=musl \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

# musl-aarch64 environment
RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=linux \
    HOST_OS=musl \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl

# android build
FROM musl_builder AS android_builder

# android package builders
COPY backends/bash/android \
     /sources/

# android-aarch64 environment
RUN HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=30 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# android-x86_64 environment
RUN HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=30 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# windows build
FROM android_builder AS windows_builder

# windows package builders
COPY backends/bash/windows \
     /sources/

# windows-x86_64 environment
RUN HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=w64 \
    HOST_OS=mingw \
    HOST_OS_API_LEVEL=64 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows

# windows-i786 environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=prescott \
        HOST_CPU=westmere \
        HOST_KERNEL=w64 \
        HOST_OS=mingw \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=i786 \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows; \
    fi

# windows-aarch64 environment
RUN HOST_ARCH=armv8.5-a \
    HOST_CPU=apple-m1 \
    HOST_KERNEL=w64 \
    HOST_OS=mingw \
    HOST_OS_API_LEVEL=64 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows

# windows-armv7a environment
RUN if [ -n "${ENABLE_32_BIT_BUILD}" ]; then \
        HOST_ARCH=armv7-a+fp \
        HOST_CPU=apple-m1 \
        HOST_KERNEL=w64 \
        HOST_OS=mingw \
        HOST_OS_API_LEVEL=32 \
        HOST_PROCESSOR=armv7a \
        bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows; \
    fi

# rust build
FROM windows_builder AS rust_builder

# rust package builders
COPY backends/bash/rust \
     /sources/

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-rust-build

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]