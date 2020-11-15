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
    HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=${HOST_KERNEL} \
    HOST_OS=${HOST_OS} \
    HOST_PROCESSOR=${HOST_PROCESSOR} \
    PACKAGE_ARCH=all \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_CLASS=deb \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SYSTEM_NAME=Linux \
    VAL_VERDE_GH_TEAM=${VAL_VERDE_GH_TEAM}

ENV BUILD_PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot/usr \
    BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
    HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot/usr \
    SYSROOT=/ \
    TEMPDIR=${TEMPDIR:-/tmp}

ENV CFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    CPPFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    LDFLAGS="\
        -L${PACKAGE_PREFIX}/lib \
    " \
    SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        -Xcxx -I${PACKAGE_PREFIX}/include \
        -Xlinker -L${PACKAGE_PREFIX}/lib \
    " \
    SWIFTCFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        -L${PACKAGE_PREFIX}/lib \
    "

ENV DPKG_ADMINDIR=/var/lib/dpkg \
    LD_LIBRARY_PATH=${PACKAGE_PREFIX}/lib:${LD_LIBRARY_PATH} \
    PATH=${PACKAGE_PREFIX}/bin:${PATH}

RUN mkdir -p ${BUILD_PACKAGE_PREFIX}

# platform sdk tool wrapper scripts
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-clang \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-clang++ \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-cmake \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-configure \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-gcc-mingw32 \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ml64 \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-mslink \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-nvcc \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rc \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swiftc \
     ${BUILD_PACKAGE_PREFIX}/bin/

RUN chmod +x ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-configure \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-cmake \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-clang \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-clang++ \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-gcc-mingw32 \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-ml64 \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-mslink \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-rc \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-swift-build \
             ${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-swiftc

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-gen-deb-files \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-make-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ninja-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-package-${PACKAGE_CLASS}-build \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-package-install \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rpath-fixup \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-bash-source-scripts \
     ${BUILD_PACKAGE_PREFIX}/bin/

COPY ${VAL_VERDE_GH_TEAM}-deb-templates \
     ${BUILD_PACKAGE_PREFIX}/share

# linux sources
FROM BASE AS SOURCES_BUILDER

RUN git clone https://github.com/${VAL_VERDE_GH_TEAM}/llvm-project.git \
              --branch val-verde-mainline-next \
              --single-branch \
              /sources/llvm-project

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
     ${VAL_VERDE_GH_TEAM}-platform-sdk-graphics-sdk-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-icu4c \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-jwasm \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-kernel-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-khr-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libarchive-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcap-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libedit-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libffi-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libiconv-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libmicrohttpd-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libssh2-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libunwind-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libuv-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libxml2-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-gnu \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-bootstrap \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-lua-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-make-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-musl-libc \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ncurses-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-ninja-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-node-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-npm-yarn-cross \
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
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-package-manager \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-syntax-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tensorflow-apis \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swig-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-systemd \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-tar-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-util-linux-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-headers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-loader-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-tools-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-vulkan-validation-layers-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wget-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-xz-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yams \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-z3-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-zlib-cross \
     /sources/

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

# kernel headers builds
FROM SOURCES_BUILDER AS KERNEL_HEADERS_BUILDER

RUN CC=/usr/bin/clang \
    MAKE_PROGRAM=/usr/bin/make \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-kernel-headers-cross

# musl libc build
FROM KERNEL_HEADERS_BUILDER AS MUSL_LIBC_BUILDER

# RUN BINDIR=/usr/bin \
#     CC=/usr/bin/clang \
#     bash ${VAL_VERDE_GH_TEAM}-platform-sdk-musl-libc

# libunwind bootstrap build
FROM MUSL_LIBC_BUILDER AS LIBUNWIND_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    CFLAGS="\
        -rtlib=compiler-rt \
        ${CFLAGS} \
    " \
    CXXFLAGS="\
        -rtlib=compiler-rt \
        ${CXXFLAGS} \
    " \
    LLVM_NATIVE_STAGE_ROOT=/usr \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libunwind-cross

# libcxxabi bootstrap build
FROM LIBUNWIND_BOOTSTRAP_BUILDER AS LIBCXXABI_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    LLVM_NATIVE_STAGE_ROOT=/usr \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-cross

# libcxx bootstrap build
FROM LIBCXXABI_BOOTSTRAP_BUILDER AS LIBCXX_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    CFLAGS="\
        -rtlib=compiler-rt \
        ${CFLAGS} \
    " \
    CXXFLAGS="\
        -rtlib=compiler-rt \
        ${CXXFLAGS} \
    " \
    LLVM_NATIVE_STAGE_ROOT=/usr \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-cross

# llvm bootstrap build
FROM LIBCXX_BOOTSTRAP_BUILDER AS LLVM_BOOTSTRAP_BUILDER

RUN MAKE_PROGRAM=/usr/bin/ninja \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-bootstrap

# remove host compiler and libraries as it is superceded by bootstrapped clang
RUN apt remove -y clang \
                  clang-10 \
                  libc++-dev \
                  libc++1 \
                  libunwind-dev \
                  lld \
                  lld-10 \
                  llvm \
                  llvm-10 \
    && apt autoremove -y

FROM LLVM_BOOTSTRAP_BUILDER AS LLVM_DEPENDENCIES_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-gnu

# remove host tools as they are superceded by native equivalents
RUN apt remove -y cmake \
                  bison \
                  expat \
                  git \
                  libedit-dev \
                  libelf-dev \
                  libicu-dev \
                  libncurses-dev \
                  libsqlite3-dev \
                  libssl-dev \
                  libxml2-dev \
                  libz3-dev \
                  ninja-build \
                  uuid-dev \
    && apt autoremove -y

ENV PYTHONHOME=${PACKAGE_PREFIX}

# llvm build
FROM LLVM_DEPENDENCIES_BUILDER AS LLVM_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project

# cmark build
FROM LLVM_BUILDER AS CMARK_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-cmark

# swift build
FROM CMARK_BUILDER AS SWIFT_BUILDER

RUN CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CXXFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift

# lldb build
FROM SWIFT_BUILDER AS LLDB_BUILDER

RUN CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CXXFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb

# libdispatch build
FROM LLDB_BUILDER AS LIBDISPATCH_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-libdispatch

# foundation build
FROM LIBDISPATCH_BUILDER AS FOUNDATION_BUILDER

RUN CFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-foundation

# xctest build
FROM FOUNDATION_BUILDER AS XCTEST_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-xctest

# llbuild build
FROM XCTEST_BUILDER AS LLBUILD_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild

# swift-tools-support-core build
FROM LLBUILD_BUILDER AS SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core

# yams build
FROM SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS YAMS_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-yams

# swift argument parser build
FROM YAMS_BUILDER AS SWIFT_ARGUMENT_PARSER_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-argument-parser

# swift-driver build
FROM SWIFT_ARGUMENT_PARSER_BUILDER AS SWIFT_DRIVER_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-driver

# swiftpm build
FROM SWIFT_DRIVER_BUILDER AS SWIFTPM_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-package-manager

RUN dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-argument-parser-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-xctest-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-driver-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-llbuild-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-package-manager-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-tools-support-core-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-yams-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb

# swift-syntax build
FROM SWIFTPM_BUILDER AS SWIFT_SYNTAX_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-syntax-cross

# swift-format build
FROM SWIFT_SYNTAX_BUILDER AS SWIFT_FORMAT_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-format-cross

# swift-doc build
FROM SWIFT_FORMAT_BUILDER AS SWIFT_DOC_BUILDER

RUN SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        ${SWIFT_BUILD_FLAGS} \
    " \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-doc-cross

# sourcekit-lsp build
FROM SWIFT_DOC_BUILDER AS SOURCEKIT_LSP_BUILDER

RUN DISABLE_POLLY=TRUE \
    SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        ${SWIFT_BUILD_FLAGS} \
    " \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp

# baikonur build
FROM SOURCEKIT_LSP_BUILDER AS BAIKONUR_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-baikonur

# pythonkit build
FROM BAIKONUR_BUILDER AS PYTHONKIT_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-pythonkit

# swift tensorflows apis build
# RUN DISABLE_POLLY=TRUE \
#    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tensorflow-apis

# graphics sdk build
FROM PYTHONKIT_BUILDER AS GRAPHICS_SDK_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-graphics-sdk-cross

# node + sdk build
FROM GRAPHICS_SDK_BUILDER AS NODE_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-node-cross
RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-npm-yarn-cross

# rust build
FROM NODE_BUILDER AS RUST_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-rust

# android-ndk package
FROM RUST_BUILDER AS ANDROID_NDK_BUILDER

ENV ANDROID_NDK_VERSION=r21d

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk

# webassembly environment
FROM ANDROID_NDK_BUILDER AS WASI_SOURCES_BUILDER

ENV HOST_ARCH=wasm32 \
    HOST_CPU=wasm32 \
    HOST_KERNEL=unknown \
    HOST_OS=wasi \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=wasm32

ENV HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSTEM_NAME=Wasi

    ENV CFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    CPPFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
    " \
    SWIFT_BUILD_FLAGS= \
    LDFLAGS="\
        -L${PACKAGE_PREFIX}/lib \
    " \
    SWIFTCFLAGS="\
        -sdk ${SYSROOT} \
    "

COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-wasi \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wasi-compiler-deps \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-wasi-libc \
     /sources/

# webassembly compiler dependencies
FROM WASI_SOURCES_BUILDER AS WASI_COMPILER_DEPS_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-wasi-compiler-deps

# android build
FROM WASI_COMPILER_DEPS_BUILDER AS ANDROID_BUILDER

# platform independent package builders
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-icu4c-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-pythonkit-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-rust-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-sourcekit-lsp-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-argument-parser-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-cmark-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-foundation-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-corelibs-xctest-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-driver-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-lldb-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-package-manager-cross \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-yams-cross \
     /sources/

# android package builders
COPY ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk-headers \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-android-ndk-runtime \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-project-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-llbuild-android \
     ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-support-core-android \
     /sources/

ENV SYSTEM_NAME=Linux

# android-aarch64 environment
ENV HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# android-x86_64 environment
ENV HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=x86_64

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-android

# windows environment
FROM ANDROID_BUILDER AS WINDOWS_SOURCES_BUILDER

ENV HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64

ENV HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk/${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSTEM_NAME=Windows

ENV CFLAGS= \
    CPPFLAGS= \
    CXXFLAGS= \
    LDFLAGS= \
    SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        -Xcxx -I${PACKAGE_PREFIX}/include \
        -Xlinker -L${PACKAGE_PREFIX}/lib \
    " \
    SWIFTCFLAGS="\
        -sdk ${SYSROOT} \
    "

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

# windows mingw-headers build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_MINGW_HEADERS_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-mingw-w64-headers

# windows mingw-crt build
FROM WINDOWS_MINGW_HEADERS_BUILDER AS WINDOWS_MINGW_CRT_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-mingw-w64-crt

# windows compiler-rt build (for host)
FROM WINDOWS_MINGW_CRT_BUILDER AS WINDOWS_COMPILER_RT_BUILDER

RUN CLANG_RT_LIB=libclang_rt.builtins-${HOST_PROCESSOR}.a \
    DST_CLANG_RT_LIB=libclang_rt.builtins-${HOST_PROCESSOR}.a \
    LDFLAGS="-Wl,/force:unresolved" \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-compiler-rt

# windows libunwind build
FROM WINDOWS_COMPILER_RT_BUILDER AS WINDOWS_LIBUNWIND_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libunwind-windows

# windows mingw-winpthreads build
FROM WINDOWS_LIBUNWIND_BUILDER AS WINDOWS_MINGW_WINPTHREADS_BUILDER

RUN export LD=${BUILD_PACKAGE_PREFIX}/bin/${VAL_VERDE_GH_TEAM}-platform-sdk-mslink \
    && bash ${VAL_VERDE_GH_TEAM}-platform-sdk-winpthreads-cross

# windows libcxxabi build
FROM WINDOWS_MINGW_WINPTHREADS_BUILDER AS WINDOWS_LIBCXXABI_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxxabi-windows

# windows libcxx build
FROM WINDOWS_LIBCXXABI_BUILDER AS WINDOWS_LIBCXX_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${VAL_VERDE_GH_TEAM}-platform-sdk-libcxx-windows

# windows llvm dependencies
FROM WINDOWS_LIBCXX_BUILDER AS WINDOWS_LLVM_DEPENDENCIES_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-llvm-dependencies-windows

# windows swift tools build
FROM WINDOWS_LLVM_DEPENDENCIES_BUILDER AS WINDOWS_SWIFT_TOOLS_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-tools-windows

# windows swift sdk build
FROM WINDOWS_SWIFT_TOOLS_BUILDER AS WINDOWS_SWIFT_SDK_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-swift-sdk-windows

# windows graphics sdk build
FROM WINDOWS_SWIFT_SDK_BUILDER AS WINDOWS_GRAPHICS_SDK_BUILDER

RUN bash ${VAL_VERDE_GH_TEAM}-platform-sdk-graphics-sdk-cross

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
