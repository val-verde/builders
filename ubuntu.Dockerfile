ARG OS_RELEASE_VERSION=${OS_RELEASE_VERSION}
FROM ubuntu:${OS_RELEASE_VERSION} AS ubuntu

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /sources

COPY ubuntu \
     /sources/
RUN bash install-host-packages

ARG PACKAGE_ARCHIVE_CLASS
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT
ARG VAL_VERDE_GH_TEAM

ENV ANDROID_NDK_VERSION=r23b \
    CUDA_VERSION=11.6.1 \
    MACOS_VERSION=12 \
    PYTHON_VERSION=3.10 \
    PACKAGE_ARCHIVE_CLASS=${PACKAGE_ARCHIVE_CLASS} \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    BOOTSTRAP_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/archives/bootstraps/${PACKAGE_ARCHIVE_CLASS} \
    RELEASE_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/archives/releases/${PACKAGE_ARCHIVE_CLASS} \
    SOURCE_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/archives/sources/${PACKAGE_ARCHIVE_CLASS} \
    SOURCE_ROOT_BASE=${SOURCE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/sources} \
    STAGE_ROOT_ARCHIVE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/archives/stage-roots/${PACKAGE_ARCHIVE_CLASS} \
    STAGE_ROOT_BASE=${STAGE_ROOT_BASE:-${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/staging} \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM}

ENV BUILD_ARCH=westmere \
    BUILD_CPU=westmere \
    BUILD_KERNEL=linux \
    BUILD_OS=gnu \
    BUILD_OS_API_LEVEL= \
    BUILD_PROCESSOR=x86_64

RUN mkdir -p ${BOOTSTRAP_ARCHIVE_PATH} \
             ${RELEASE_ARCHIVE_PATH} \
             ${SOURCE_ARCHIVE_PATH} \
             ${STAGE_ROOT_ARCHIVE_PATH}

# platform sdk tool wrapper scripts and templates
COPY backends/bash/archive-templates \
     /sources/archive-templates/
COPY backends/bash/packaging-tools \
     /sources/packaging-tools/

# upstream source package build
FROM ubuntu AS sources_builder

COPY /archives/sources/${PACKAGE_ARCHIVE_CLASS} \
     ${SOURCE_ARCHIVE_PATH}
COPY backends/bash/sources \
     /sources/

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-sources-builder

COPY /archives/stage-roots/${PACKAGE_ARCHIVE_CLASS} \
     ${STAGE_ROOT_ARCHIVE_PATH}

COPY /archives/bootstraps/${PACKAGE_ARCHIVE_CLASS} \
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

RUN echo "source /usr/libexec/val-verde-platform-sdk-platform-api" > ~/.bashrc
SHELL ["/bin/bash", "-c", "-l"]

RUN platform-invoke-builder binaries-builder gnu-x86_64

# gnu bootstrap build
FROM binaries_builder AS gnu_bootstrap_builder

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

RUN platform-invoke-builder gnu-bootstrap gnu-x86_64

ENV BUILD_SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_CPU}/sysroot/usr/glibc-interface

COPY /archives/releases/${PACKAGE_ARCHIVE_CLASS} \
     ${RELEASE_ARCHIVE_PATH}

# platform sdk package build scripts
COPY backends/bash/cross \
     /sources/

# system base build
FROM gnu_bootstrap_builder AS system_base_builder

# windows system base package builders
COPY backends/bash/windows-base \
     /sources/

# windows-x86_64 environment
RUN platform-invoke-builder windows-base windows-x86_64

# windows-i686 environment
RUN platform-invoke-builder windows-base windows-i686

# windows-aarch64 environment
RUN platform-invoke-builder windows-base windows-aarch64

# windows-armv7a environment
RUN platform-invoke-builder windows-base windows-armv7a

# webassembly system base package builders
COPY backends/bash/webassembly \
     /sources/

RUN platform-invoke-builder webassembly wasm32-wasm32

# gnu build
FROM system_base_builder AS gnu_builder

# gnu package builders
COPY backends/bash/gnu \
     /sources/

# gnu build environment
RUN platform-invoke-builder gnu gnu-x86_64

# gnu-aarch64 environment
RUN platform-invoke-builder binaries-builder gnu-aarch64

RUN platform-invoke-builder gnu-bootstrap gnu-aarch64

RUN platform-invoke-builder gnu gnu-aarch64

# gnu-i686 environment
# RUN platform-invoke-builder gnu-bootstrap gnu-i686

# RUN platform-invoke-builder gnu gnu-i686

# gnueabihf-armv7a environment
# RUN platform-invoke-builder gnu-bootstrap gnu-armv7a

# RUN platform-invoke-builder gnu gnu-armv7a

# macos build
FROM gnu_builder AS macos_builder

# macos package builders
COPY backends/bash/darwin \
     /sources/

RUN platform-invoke-builder compiler-rt-builder darwin-x86_64

# macos-x86_64 environment
RUN platform-invoke-builder darwin darwin-x86_64

# macos-aarch64 environment
RUN platform-invoke-builder darwin darwin-aarch64

# musl build
FROM macos_builder AS musl_builder

# musl package builders
COPY backends/bash/musl \
     /sources/

# musl-x86_64 environment
RUN platform-invoke-builder musl musl-x86_64

# musl-aarch64 environment
RUN platform-invoke-builder musl musl-aarch64

# android build
FROM musl_builder AS android_builder

# android package builders
COPY backends/bash/android \
     /sources/

# android-aarch64 environment
RUN platform-invoke-builder android android-aarch64

# android-x86_64 environment
RUN platform-invoke-builder android android-x86_64

# windows build
FROM android_builder AS windows_builder

# windows package builders
COPY backends/bash/windows \
     /sources/

# windows-x86_64 environment
RUN platform-invoke-builder windows windows-x86_64

# windows-aarch64 environment
RUN platform-invoke-builder windows windows-aarch64

FROM windows_builder AS rust_builder

# rust package builders
COPY backends/bash/rust \
     /sources/

# rust build
RUN platform-invoke-builder rust-build gnu-x86_64
 
CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
