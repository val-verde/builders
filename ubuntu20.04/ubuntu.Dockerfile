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
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SYSTEM_NAME=Linux \
    PACKAGE_CLASS=deb

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

ENV LD_LIBRARY_PATH=${PACKAGE_PREFIX}/lib:${LD_LIBRARY_PATH} \
    PATH=${PACKAGE_PREFIX}/bin:${PATH}

RUN mkdir -p ${BUILD_PACKAGE_PREFIX}

# platform sdk tool wrapper scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-configure \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
     ${PACKAGE_BASE_NAME}-platform-sdk-gcc-mingw32 \
     ${PACKAGE_BASE_NAME}-platform-sdk-ml64 \
     ${PACKAGE_BASE_NAME}-platform-sdk-mslink \
     ${PACKAGE_BASE_NAME}-platform-sdk-rc \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-swiftc \
     ${BUILD_PACKAGE_PREFIX}/bin/

RUN chmod +x ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-configure \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-cmake \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-gcc-mingw32 \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-ml64 \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-rc \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
             ${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swiftc

COPY ${PACKAGE_BASE_NAME}-platform-sdk-gen-deb-files \
     ${PACKAGE_BASE_NAME}-platform-sdk-make-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-${PACKAGE_CLASS}-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-install \
     ${PACKAGE_BASE_NAME}-platform-sdk-rpath-fixup \
     ${BUILD_PACKAGE_PREFIX}/bin/

# source patches
COPY bzip2-mingw32.diff \
     patch-coreutils-ls-android.diff \
     /sources/

# linux sources
FROM BASE AS SOURCES_BUILDER

RUN git clone https://github.com/${PACKAGE_BASE_NAME}/llvm-project.git \
              --branch dutch-master-next \
              --single-branch \
              /sources/llvm-project

# platform sdk package build scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-patch-elf-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-acl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-attr-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-autoconf-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-automake-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-baikonur \
     ${PACKAGE_BASE_NAME}-platform-sdk-bash-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-bison-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-bzip2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt \
     ${PACKAGE_BASE_NAME}-platform-sdk-coreutils-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-dpkg-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-egl-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-filament-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-gawk-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-gdbm-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-gettext-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-git-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-glslang-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-gperf-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-graphics-sdk-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c \
     ${PACKAGE_BASE_NAME}-platform-sdk-jwasm \
     ${PACKAGE_BASE_NAME}-platform-sdk-khr-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcap-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libiconv-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libssh2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-dependencies-gnu \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap \
     ${PACKAGE_BASE_NAME}-platform-sdk-lua-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-make-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-musl-libc \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-node-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-opengl-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-opengl-es-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pcre-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pkg-config-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit \
     ${PACKAGE_BASE_NAME}-platform-sdk-sdl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sed-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sourcekit-lsp \
     ${PACKAGE_BASE_NAME}-platform-sdk-spirv-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-spirv-tools-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-strace-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-argument-parser \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tensorflow-apis \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core \
     ${PACKAGE_BASE_NAME}-platform-sdk-swig-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-systemd \
     ${PACKAGE_BASE_NAME}-platform-sdk-tar-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-util-linux-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-vulkan-headers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-vulkan-loader-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-vulkan-tools-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-vulkan-validation-layers-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-wget-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams \
     ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross \
     ${PACKAGE_BASE_NAME}-deb-templates \
     /sources/

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

# musl libc build
FROM SOURCES_BUILDER AS MUSL_LIBC_BUILDER

# RUN BINDIR=/usr/bin \
#     CC=/usr/bin/clang \
#     SYSROOT=/ \
#     bash ${PACKAGE_BASE_NAME}-platform-sdk-musl-libc

# Table with 3 columns: simplified_name | ubuntu/val-verde | version 

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
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross

# libcxxabi bootstrap build
FROM LIBUNWIND_BOOTSTRAP_BUILDER AS LIBCXXABI_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    LLVM_NATIVE_STAGE_ROOT=/usr \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-cross

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
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-cross

# llvm bootstrap build
FROM LIBCXX_BOOTSTRAP_BUILDER AS LLVM_BOOTSTRAP_BUILDER

RUN MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap

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

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-dependencies-gnu

# remove host tools as they are superceded by native equivalents
RUN apt remove -y cmake \
                  bison \
                  expat \
                  git \
                  libedit-dev \
                  libffi-dev \
                  libicu-dev \
                  libncurses-dev \
                  libpython3.8 \
                  libpython3.8-dev \
                  libsqlite3-dev \
                  libssl-dev \
                  libxml2-dev \
                  libz3-dev \
                  ninja-build \
                  pkg-config \
                  python3 \
                  uuid-dev \
    && apt autoremove -y

ENV PYTHONHOME=${PACKAGE_PREFIX}

# llvm build
FROM LLVM_DEPENDENCIES_BUILDER AS LLVM_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project

# cmark build
FROM LLVM_BUILDER AS CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark

# swift build
FROM CMARK_BUILDER AS SWIFT_BUILDER

RUN CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CXXFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift

# lldb build
FROM SWIFT_BUILDER AS LLDB_BUILDER

RUN CXXFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CXXFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb

# libdispatch build
FROM LLDB_BUILDER AS LIBDISPATCH_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch

# foundation build
FROM LIBDISPATCH_BUILDER AS FOUNDATION_BUILDER

RUN CFLAGS="\
        -I${PACKAGE_PREFIX}/include \
        ${CFLAGS} \
    " \
    DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation

# xctest build
FROM FOUNDATION_BUILDER AS XCTEST_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest

# llbuild build
FROM XCTEST_BUILDER AS LLBUILD_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild

# swift-tools-support-core build
FROM LLBUILD_BUILDER AS SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core

# yams build
FROM SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS YAMS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-yams

# swift argument parser build
FROM YAMS_BUILDER AS SWIFT_ARGUMENT_PARSER_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-argument-parser

# swift-driver build
FROM SWIFT_ARGUMENT_PARSER_BUILDER AS SWIFT_DRIVER_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver

# swiftpm build
FROM SWIFT_DRIVER_BUILDER AS SWIFTPM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager

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

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross

# swift-format build
FROM SWIFT_SYNTAX_BUILDER AS SWIFT_FORMAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross

# swift-doc build
FROM SWIFT_FORMAT_BUILDER AS SWIFT_DOC_BUILDER

RUN SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        ${SWIFT_BUILD_FLAGS} \
    " \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-cross

# sourcekit-lsp build
FROM SWIFT_DOC_BUILDER AS SOURCEKIT_LSP_BUILDER

RUN DISABLE_POLLY=TRUE \
    SWIFT_BUILD_FLAGS="\
        -Xcc -I${PACKAGE_PREFIX}/include \
        ${SWIFT_BUILD_FLAGS} \
    " \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-sourcekit-lsp

# baikonur build
FROM SOURCEKIT_LSP_BUILDER AS BAIKONUR_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash val-verde-platform-sdk-baikonur

# pythonkit build
FROM BAIKONUR_BUILDER AS PYTHONKIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit

# swift tensorflows apis build
# RUN DISABLE_POLLY=TRUE \
#    bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tensorflow-apis

# graphics sdk build
FROM PYTHONKIT_BUILDER AS GRAPHICS_SDK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-graphics-sdk-cross

# node build
FROM GRAPHICS_SDK_BUILDER AS NODE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-node-cross

# android-ndk package/
FROM NODE_BUILDER AS ANDROID_NDK_BUILDER

ENV ANDROID_NDK_VERSION=r21d

RUN mkdir /sources/android-ndk-${ANDROID_NDK_VERSION}

# android ndk patches
COPY android-ndk-dirent-versionsort.diff \
     android-ndk-linux-time-h.diff \
     android-ndk-string-strverscmp.diff \
     /sources/android-ndk-${ANDROID_NDK_VERSION}/

RUN PACKAGE_ARCH=${BUILD_PROCESSOR} \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk

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

COPY ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-wasi-compiler-deps \
     ${PACKAGE_BASE_NAME}-platform-sdk-wasi-libc \
     /sources/

# webassembly compiler dependencies
FROM WASI_SOURCES_BUILDER AS WASI_COMPILER_DEPS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-wasi-compiler-deps

# android build
FROM WASI_COMPILER_DEPS_BUILDER AS ANDROID_BUILDER

# platform independent package builders
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sourcekit-lsp-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-argument-parser-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross \
     /sources/

# android package builders
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-dependencies-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-android \
     /sources/

ENV SYSTEM_NAME=Linux

# android-aarch64 environment
ENV HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64

RUN dpkg --add-architecture ${HOST_PROCESSOR}
RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android || true

# android-x86_64 environment
ENV HOST_ARCH=westmere \
    HOST_CPU=westmere \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=x86_64

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android || true

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

COPY ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-dependencies-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-crt \
     ${PACKAGE_BASE_NAME}-platform-sdk-sourcekit-lsp-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-sdk-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-wineditline-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-windows \
     /sources/

# mingw-w64 source
RUN export SOURCE_PACKAGE_NAME=mingw-w64 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && git clone https://github.com/${PACKAGE_BASE_NAME}/${SOURCE_PACKAGE_NAME}.git \
                 --branch dutch-master \
                 --single-branch \
                 ${SOURCE_ROOT}

# windows mingw-headers build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_MINGW_HEADERS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-headers

# windows mingw-crt build
FROM WINDOWS_MINGW_HEADERS_BUILDER AS WINDOWS_MINGW_CRT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-crt

# windows compiler-rt build (for host)
FROM WINDOWS_MINGW_CRT_BUILDER AS WINDOWS_COMPILER_RT_BUILDER

RUN CLANG_RT_LIB=libclang_rt.builtins-${HOST_PROCESSOR}.a \
    DST_CLANG_RT_LIB=libclang_rt.builtins-${HOST_PROCESSOR}.a \
    LDFLAGS="-Wl,/force:unresolved" \
    PACKAGE_ARCH=${BUILD_PROCESSOR} \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt

# windows libunwind build
FROM WINDOWS_COMPILER_RT_BUILDER AS WINDOWS_LIBUNWIND_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-windows

# windows mingw-winpthreads build
FROM WINDOWS_LIBUNWIND_BUILDER AS WINDOWS_MINGW_WINPTHREADS_BUILDER

RUN export LD=${BUILD_PACKAGE_PREFIX}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross

# windows libcxxabi build
FROM WINDOWS_MINGW_WINPTHREADS_BUILDER AS WINDOWS_LIBCXXABI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows

# windows libcxx build
FROM WINDOWS_LIBCXXABI_BUILDER AS WINDOWS_LIBCXX_BUILDER

RUN DISABLE_POLLY=TRUE \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows

# windows llvm dependencies
FROM WINDOWS_LIBCXX_BUILDER AS WINDOWS_LLVM_DEPENDENCIES_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-dependencies-windows

# windows swift tools build
FROM WINDOWS_LLVM_DEPENDENCIES_BUILDER AS WINDOWS_SWIFT_TOOLS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-windows

# windows swift sdk build
FROM WINDOWS_SWIFT_TOOLS_BUILDER AS WINDOWS_SWIFT_SDK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-sdk-windows

# windows graphics sdk build
FROM WINDOWS_SWIFT_SDK_BUILDER AS WINDOWS_GRAPHICS_SDK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-graphics-sdk-cross

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
