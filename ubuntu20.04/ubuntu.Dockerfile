FROM ubuntu:20.04 AS BASE

ENV DEBIAN_FRONTEND=noninteractive

ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT

WORKDIR /sources

ENV BOOTSTRAP_SCRIPT=bootstrap-${HOST_OS}-toolchain

COPY ${BOOTSTRAP_SCRIPT} .
RUN bash ${BOOTSTRAP_SCRIPT}

ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT
ARG VAL_VERDE_GH_TEAM

ENV BUILD_ARCH=haswell \
    BUILD_CPU=skylake \
    BUILD_KERNEL=${BUILD_KERNEL} \
    BUILD_OS=${BUILD_OS} \
    BUILD_OS_API_LEVEL= \
    BUILD_PROCESSOR=${BUILD_PROCESSOR} \
    DEB_PATH=${DEB_PATH} \
    DPKG_ADMINDIR=/var/lib/dpkg \
    PACKAGE_ARCH=all \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_CLASS=deb \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    NODE_PATH=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/web \
    TEMPDIR=${TEMPDIR:-/tmp} \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM}

ENV BUILD_PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH}/sysroot/usr \
    BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}

ENV PATH=${BUILD_PACKAGE_PREFIX}/bin:${PATH} \
    LD_LIBRARY_PATH=${BUILD_PACKAGE_PREFIX}/lib

RUN mkdir -p ${BUILD_PACKAGE_PREFIX} \
             ${NODE_PATH}

# platform sdk tool wrapper scripts
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-clang \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-clang++ \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gcc-mingw32 \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ml64 \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-mslink \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rc \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swiftc \
     ${BUILD_PACKAGE_PREFIX}/bin/

RUN chmod +x ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-clang \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-clang++ \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-gcc-mingw32 \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-ml64 \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-mslink \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-rc \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-swiftc

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-bash-source-scripts \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gen-deb-files \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-make-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ninja-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-package-${PACKAGE_CLASS}-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-package-install \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rpath-fixup \
     ${BUILD_PACKAGE_PREFIX}/bin/

COPY ${VAL_VERDE_GH_TEAM}-deb-templates \
     ${BUILD_PACKAGE_PREFIX}/share

# linux sources
FROM BASE AS SOURCES_BUILDER

RUN git clone https://github.com/${VAL_VERDE_GH_TEAM}/llvm-project.git \
              --branch val-verde-mainline-next \
              --single-branch \
              /sources/llvm-project

# platform sdk bootstrap package build scripts
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libunwind-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-bootstrap \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-openjdk-bootstrap \
     /sources/

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

# gnu bootstrap build
FROM SOURCES_BUILDER AS GNU_BOOTSTRAP_BUILDER

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu-bootstrap

# platform sdk package build scripts
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-android-patch-elf-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-acl-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-attr-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-autoconf-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-automake-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-baikonur \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-bash-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-bison-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-bzip2-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-cmake-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-coreutils-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-curl-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-dpkg-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-egl-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-elfutils-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-expat-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-filament-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gawk-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gdbm-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gettext-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-git-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-glslang-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gperf-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-graphics-sdk-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-icu4c \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-jwasm \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-kernel-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-khr-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libarchive-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcap-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libedit-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libffi-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libiconv-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libmicrohttpd-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libsecret-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libssh2-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libtool-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libuv-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libxml2-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-gnu \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-lua-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-m4-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-make-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ncurses-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ninja-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-node-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-npm-yarn-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-openjdk-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-openssl-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-opengl-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-opengl-es-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-pcre-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-python-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-pkg-config-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-pythonkit \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rust \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sdl-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sed-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-spirv-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-spirv-tools-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sqlite-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-strace-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-argument-parser \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-cmark \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-foundation \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-libdispatch \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-xctest \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-doc-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-driver \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-format-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-package-manager \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-syntax-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tensorflow-apis \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swig-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-systemd \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-tar-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-unzip-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-util-linux-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vim-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-loader-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-tools-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-validation-layers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wget-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-xz-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yams \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yarn-yautja-server-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-z3-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-zip-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-zlib-cross \
     /sources/

# gnu build
FROM GNU_BOOTSTRAP_BUILDER AS GNU_BUILDER

RUN HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-gnu

# platform independent package builders
FROM GNU_BUILDER AS PLATFORM_INDEPENDENT_PACKAGE_BUILDERS

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-gnulib-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-icu4c-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-pythonkit-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rust-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-argument-parser-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-cmark-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-foundation-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-xctest-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-driver-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-package-manager-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yams-cross \
     /sources/

# musl build
FROM PLATFORM_INDEPENDENT_PACKAGE_BUILDERS AS MUSL_BUILDER

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-musl-fts \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-musl-headers \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-musl-libc \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-sdk-musl \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-musl \
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

RUN ANDROID_NDK_VERSION=r21d \
    HOST_ARCH=${BUILD_ARCH} \
    HOST_CPU=${BUILD_CPU} \
    HOST_KERNEL=${BUILD_KERNEL} \
    HOST_OS=${BUILD_OS} \
    HOST_PROCESSOR=${BUILD_PROCESSOR} \
    SYSROOT=/ \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk

# webassembly build
FROM ANDROID_NDK_BUILDER AS WEBASSEMBLY_BUILDER

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-webassembly \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wasi-libc \
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
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk-headers \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk-runtime \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core-android \
     /sources/

# android-aarch64 environment
RUN ANDROID_NDK_VERSION=r21d \
    HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# android-x86_64 environment
RUN ANDROID_NDK_VERSION=r21d \
    HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# windows environment
FROM ANDROID_BUILDER AS WINDOWS_SOURCES_BUILDER

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libunwind-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-mingw-w64-headers \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-mingw-w64-crt \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-foundation-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-libdispatch-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-xctest-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-sdk-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-windows \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wineditline-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-winpthreads-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yams-windows \
     /sources/

# mingw-w64 source
RUN export SOURCE_PACKAGE_NAME=mingw-w64 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && git clone https://github.com/${VAL_VERDE_GH_TEAM}/${SOURCE_PACKAGE_NAME}.git \
                 --branch val-verde-mainline \
                 --single-branch \
                 ${SOURCE_ROOT}

# windows build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_BUILDER

RUN HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64 \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-windows

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
