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
    HOST_KERNEL=${HOST_KERNEL} \
    HOST_OS=${HOST_OS} \
    HOST_PROCESSOR=${HOST_PROCESSOR} \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SYSROOT=/ \
    SYSTEM_NAME=Linux

ENV BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
    HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}

ENV LD_LIBRARY_PATH=${PACKAGE_ROOT}/lib

# platform sdk tool wrapper scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-configure \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
     ${PACKAGE_BASE_NAME}-platform-sdk-ml64 \
     ${PACKAGE_BASE_NAME}-platform-sdk-mslink \
     ${PACKAGE_BASE_NAME}-platform-sdk-rc \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-swiftc \
     ${PACKAGE_ROOT}/bin/

RUN chmod +x ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-cmake \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-ml64 \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-rc \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swiftc

COPY ${PACKAGE_BASE_NAME}-platform-sdk-make-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-install \
     /sources/

# linux sources
FROM BASE AS SOURCES_BUILDER

RUN git clone https://github.com/${PACKAGE_BASE_NAME}/llvm-project.git \
              --branch dutch-master \
              --single-branch \
              /sources/llvm-project

# platform sdk package build scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt \
     ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-git-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c \
     ${PACKAGE_BASE_NAME}-platform-sdk-jwasm \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libssh2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core \
     ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams \
     ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross \
     /sources/

# libunwind bootstrap build
FROM SOURCES_BUILDER AS LIBUNWIND_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    LLVM_NATIVE_STAGE_ROOT=/usr \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross

# llvm bootstrap build
FROM LIBUNWIND_BOOTSTRAP_BUILDER AS LIBCXXABI_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-cross

# llvm bootstrap build
FROM LIBCXXABI_BOOTSTRAP_BUILDER AS LIBCXX_BOOTSTRAP_BUILDER

RUN BINDIR=/usr/bin \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-cross

# llvm bootstrap build
FROM LIBCXX_BOOTSTRAP_BUILDER AS LLVM_BOOTSTRAP_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap
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

# LTO configuration: [OFF | Full | Thin]
# ENV ENABLE_FLTO=Thin

# Optimization level speed: [0-3] or size: [s, z]
ENV OPTIMIZATION_LEVEL=3

# zlib build
FROM LLVM_BOOTSTRAP_BUILDER AS ZLIB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross

# icu build
FROM ZLIB_BUILDER AS ICU_BUILDER

COPY icu-uconfig-prepend.h .

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c

# xz build
FROM ICU_BUILDER AS XZ_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross

# libxml2 build
FROM XZ_BUILDER AS LIBXML2_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross

# libuuid build
FROM LIBXML2_BUILDER AS UUID_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross

# ncurses build
FROM UUID_BUILDER AS NCURSES_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross

# libedit build
FROM NCURSES_BUILDER AS LIBEDIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross

# sqlite3 build
FROM LIBEDIT_BUILDER AS SQLITE3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross

# libssh2 build
FROM SQLITE3_BUILDER AS LIBSSH2_BUILDER

RUN CMAKE_BINDIR=/usr/bin \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-libssh2-cross

# curl build
FROM LIBSSH2_BUILDER AS CURL_BUILDER

RUN CMAKE_BINDIR=/usr/bin \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross

# libexpat build
FROM CURL_BUILDER AS LIBEXPAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross

# libffi build
FROM LIBEXPAT_BUILDER AS LIBFFI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross

# libpython build
FROM LIBFFI_BUILDER AS LIBPYTHON_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-python-cross

# z3 build
FROM LIBPYTHON_BUILDER AS Z3_BUILDER

RUN CMAKE_BINDIR=/usr/bin \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross

# git build
FROM Z3_BUILDER AS GIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-git-cross

# ninja build
FROM GIT_BUILDER AS NINJA_BUILDER

RUN CMAKE_BINDIR=/usr/bin \
    MAKE_PROGRAM=/usr/bin/ninja \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-ninja-cross

# cmake build
FROM NINJA_BUILDER AS CMAKE_BUILDER

RUN CMAKE_BINDIR=/usr/bin \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-cmake-cross

# llvm build
FROM CMAKE_BUILDER AS LLVM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
    && apt remove -y cmake \
                     git \
                     libedit-dev \
                     libffi-dev \
                     libicu-dev \
                     libncurses-dev \
                     libpython2.7 \
                     libpython2.7-dev \
                     libsqlite3-dev \
                     libxml2-dev \
                     libz3-dev \
                     ninja-build \
                     uuid-dev \
                     zlib1g-dev \
    && apt autoremove -y

# cmark build
FROM LLVM_BUILDER AS CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark

# swift build
FROM CMARK_BUILDER AS SWIFT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift

# lldb build
FROM SWIFT_BUILDER AS LLDB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb

# libdispatch build
FROM LLDB_BUILDER AS LIBDISPATCH_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch

# foundation build
FROM LIBDISPATCH_BUILDER AS FOUNDATION_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation

# xctest build
FROM FOUNDATION_BUILDER AS XCTEST_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest

# llbuild build
FROM XCTEST_BUILDER AS LLBUILD_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild

# swift-tools-support-core build
FROM LLBUILD_BUILDER AS SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core

# yams build
FROM SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS YAMS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-yams

# swift-driver build
FROM YAMS_BUILDER AS SWIFT_DRIVER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver

# swiftpm build
FROM SWIFT_DRIVER AS SWIFTPM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager

RUN dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb

# swift-syntax build
FROM SWIFTPM_BUILDER AS SWIFT_SYNTAX_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax

# swift-format build
FROM SWIFT_SYNTAX_BUILDER AS SWIFT_FORMAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-format

# swift-doc build
FROM SWIFT_FORMAT_BUILDER AS SWIFT_DOC_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc

# pythonkit build
FROM SWIFT_DOC_BUILDER AS PYTHONKIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit

# jwasm (ml64) cross compiler
FROM PYTHONKIT_BUILDER AS JWASM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-jwasm

# android-ndk package
FROM JWASM_BUILDER AS ANDROID_NDK_BUILDER

ENV ANDROID_NDK_VERSION=r21d

RUN export SOURCE_PACKAGE_NAME=android-ndk \
    && export SOURCE_PACKAGE_VERSION=${ANDROID_NDK_VERSION} \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && mkdir ${SOURCE_ROOT}

COPY android-ndk-linux-time-h.diff /sources/android-ndk-${ANDROID_NDK_VERSION}

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk

# platform independent package builders
COPY ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libgcc-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross \
     /sources/

# android package builders
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-android \
     /sources/

# android environment
ENV HOST_ARCH=armv8-a \
    HOST_CPU=cortex-a57 \
    HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64

ENV HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot/usr \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSTEM_NAME=Linux

# android ndk headers build
FROM ANDROID_NDK_BUILDER AS ANDROID_NDK_HEADERS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers

# android ndk runtime build
FROM ANDROID_NDK_HEADERS_BUILDER AS ANDROID_NDK_RUNTIME_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime

# android compiler-rt build (for host)
FROM ANDROID_NDK_RUNTIME_BUILDER AS ANDROID_COMPILER_RT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt

# android libunwind build
FROM ANDROID_COMPILER_RT_BUILDER AS ANDROID_LIBUNWIND_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross

# android icu build
FROM ANDROID_LIBUNWIND_BUILDER AS ANDROID_ICU_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross

# android xz build
FROM ANDROID_ICU_BUILDER AS ANDROID_XZ_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross

# android libxml2 build
FROM ANDROID_XZ_BUILDER AS ANDROID_LIBXML2_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross

# android libuuid build
FROM ANDROID_LIBXML2_BUILDER AS ANDROID_UUID_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross

# android ncurses build
FROM ANDROID_UUID_BUILDER AS ANDROID_NCURSES_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross

# android libedit build
FROM ANDROID_NCURSES_BUILDER AS ANDROID_LIBEDIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross

# android sqlite3 build
FROM ANDROID_LIBEDIT_BUILDER AS ANDROID_SQLITE3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross

# android openssl build
FROM ANDROID_SQLITE3_BUILDER AS ANDROID_OPENSSL_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross

# android libssh2 build
FROM ANDROID_OPENSSL_BUILDER AS ANDROID_LIBSSH2_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libssh2-cross

# android curl build
FROM ANDROID_LIBSSH2_BUILDER AS ANDROID_CURL_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross

# android libexpat build
FROM ANDROID_CURL_BUILDER AS ANDROID_LIBEXPAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross

# android libffi build
FROM ANDROID_LIBEXPAT_BUILDER AS ANDROID_LIBFFI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross

# android libpython build
FROM ANDROID_LIBFFI_BUILDER AS ANDROID_LIBPYTHON_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-python-cross

# android z3 build
FROM ANDROID_LIBPYTHON_BUILDER AS ANDROID_Z3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross

# android git build
FROM ANDROID_Z3_BUILDER AS ANDROID_GIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-git-cross

# android ninja build
FROM ANDROID_GIT_BUILDER AS ANDROID_NINJA_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-ninja-cross

# android cmake build
FROM ANDROID_NINJA_BUILDER AS ANDROID_CMAKE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-cmake-android

# android llvm build
FROM ANDROID_CMAKE_BUILDER AS ANDROID_LLVM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android

# android cmark build
FROM ANDROID_LLVM_BUILDER AS ANDROID_CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross

# android swift build
FROM ANDROID_CMARK_BUILDER AS ANDROID_SWIFT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-android

# android lldb build
FROM ANDROID_SWIFT_BUILDER AS ANDROID_LLDB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-cross

# android libdispatch build
FROM ANDROID_LLDB_BUILDER AS ANDROID_LIBDISPATCH_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross

# remove host foundation and libdispatch to avoid module collisions
RUN apt remove -y ${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH} \
                  ${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH}

# android foundation build
FROM ANDROID_LIBDISPATCH_BUILDER AS ANDROID_FOUNDATION_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross

# android xctest build
FROM ANDROID_FOUNDATION_BUILDER AS ANDROID_XCTEST_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross

# android llbuild build
FROM ANDROID_XCTEST_BUILDER AS ANDROID_LLBUILD_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android

# android swift-tools-support-core build
FROM ANDROID_LLBUILD_BUILDER AS ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-android

# android yams build
FROM ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS ANDROID_YAMS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross

# android swift-driver build
FROM ANDROID_YAMS_BUILDER AS ANDROID_SWIFT_DRIVER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross

# android swiftpm build
FROM ANDROID_SWIFT_DRIVER AS ANDROID_SWIFTPM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross

RUN dpkg -i /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}.deb

# android swift-syntax build
FROM ANDROID_SWIFTPM_BUILDER AS ANDROID_SWIFT_SYNTAX_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross

# android swift-format build
FROM ANDROID_SWIFT_SYNTAX_BUILDER AS ANDROID_SWIFT_FORMAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross

# android swift-doc build
FROM ANDROID_SWIFT_FORMAT_BUILDER AS ANDROID_SWIFT_DOC_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android

# android pythonkit build
FROM ANDROID_SWIFT_DOC_BUILDER AS ANDROID_PYTHONKIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross

# windows environment
FROM ANDROID_PYTHONKIT_BUILDER AS WINDOWS_SOURCES_BUILDER

ENV HOST_ARCH=haswell \
    HOST_CPU=skylake \
    HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64

ENV HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSTEM_NAME=Windows

COPY ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-crt \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-sdk-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-wineditline-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-windows \
     /sources/

COPY mingw-sdk.modulemap \
     /sources/

# mingw-w64 source
RUN export SOURCE_PACKAGE_NAME=mingw-w64 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && git clone https://github.com/${PACKAGE_BASE_NAME}/${SOURCE_PACKAGE_NAME}.git \
                 --branch master \
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

RUN export CLANG_RT_LIB=clang_rt.builtins-${HOST_PROCESSOR}.lib \
           DST_CLANG_RT_LIB=libclang_rt.builtins-${HOST_PROCESSOR}.a \
           LDFLAGS="-Wl,/force:unresolved" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt

# windows mingw-winpthreads build
FROM WINDOWS_COMPILER_RT_BUILDER AS WINDOWS_MINGW_WINPTHREADS_BUILDER

RUN export LD=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross

# windows libunwind build
FROM WINDOWS_MINGW_WINPTHREADS_BUILDER AS WINDOWS_LIBUNWIND_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-windows

# windows libcxxabi build
FROM WINDOWS_LIBUNWIND_BUILDER AS WINDOWS_LIBCXXABI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows

# windows libcxx build
FROM WINDOWS_LIBCXXABI_BUILDER AS WINDOWS_LIBCXX_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows

# windows zlib build
FROM WINDOWS_LIBCXX_BUILDER AS WINDOWS_ZLIB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross

# windows icu build
FROM WINDOWS_ZLIB_BUILDER AS WINDOWS_ICU_BUILDER

RUN LDFLAGS="\
        -fuse-ld=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
        ${LDFLAGS} \
    " \
    LIBS="\
        -lucrt \
        ${LIBS} \
    " \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross

# windows xz build
FROM WINDOWS_ICU_BUILDER AS WINDOWS_XZ_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross

# windows libxml2 build
FROM WINDOWS_XZ_BUILDER AS WINDOWS_LIBXML2_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross

# android ncurses build
FROM WINDOWS_LIBXML2_BUILDER AS WINDOWS_NCURSES_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross

# windows editline build
FROM WINDOWS_NCURSES_BUILDER AS WINDOWS_WINEDITLINE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-wineditline-cross

# windows sqlite3 build
FROM WINDOWS_WINEDITLINE_BUILDER AS WINDOWS_SQLITE3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross

# windows openssl build
FROM WINDOWS_SQLITE3_BUILDER AS WINDOWS_OPENSSL_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-openssl-windows

# windows libssh2 build
FROM WINDOWS_OPENSSL_BUILDER AS WINDOWS_LIBSSH2_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libssh2-cross

# windows curl build
FROM WINDOWS_LIBSSH2_BUILDER AS WINDOWS_CURL_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross

# windows libexpat build
FROM WINDOWS_CURL_BUILDER AS WINDOWS_LIBEXPAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross

# windows libffi build
FROM WINDOWS_LIBEXPAT_BUILDER AS WINDOWS_LIBFFI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross

# windows libpython build
FROM WINDOWS_LIBFFI_BUILDER AS WINDOWS_LIBPYTHON_BUILDER

# COPY ${PACKAGE_BASE_NAME}-platform-sdk-python-cross-new \
#      /sources/${PACKAGE_BASE_NAME}-platform-sdk-python-cross
# COPY patch-python /sources

# RUN export CONFIGURE_FLAGS="--host=${TARGET_PROCESSOR}-${TARGET_KERNEL}-cygwin" \
#            CFLAGS="-fms-extensions -fms-compatibility-version=19 -DMS_NO_COREDLL=1 -DMS_WINDOWS=1 -v -D_UWIN=1" \
#            LDFLAGS="-Wl,/force:multiple" \
#            DYNLOADFILE=dynload_win.o \
#     && bash ${PACKAGE_BASE_NAME}-platform-sdk-python-cross || true

# windows z3 build
FROM WINDOWS_LIBPYTHON_BUILDER AS WINDOWS_Z3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross

FROM WINDOWS_Z3_BUILDER AS WINDOWS_JWASM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-jwasm

# windows ninja build
FROM WINDOWS_JWASM_BUILDER AS WINDOWS_NINJA_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-ninja-cross

# windows cmake build
FROM WINDOWS_NINJA_BUILDER AS WINDOWS_CMAKE_BUILDER

RUN LIBS="\
        -lole32 \
        -loleaut32\
        ${LIBS} \
    " \
    bash ${PACKAGE_BASE_NAME}-platform-sdk-cmake-cross

# windows llvm build
FROM WINDOWS_CMAKE_BUILDER AS WINDOWS_LLVM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-windows

# windows cmark build
FROM WINDOWS_LLVM_BUILDER AS WINDOWS_CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross

# windows swift build
FROM WINDOWS_CMARK_BUILDER AS WINDOWS_SWIFT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-windows

# windows lldb build
FROM WINDOWS_SWIFT_BUILDER AS WINDOWS_LLDB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-windows

# remove host foundation and libdispatch to avoid module collisions
RUN apt remove -y ${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH} \
                  ${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}${BUILD_OS_API_LEVEL}-${BUILD_ARCH}

# windows swift sdk build
FROM WINDOWS_LLDB_BUILDER AS WINDOWS_SWIFT_SDK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-sdk-windows

# webassembly environment
FROM WINDOWS_SWIFT_SDK_BUILDER AS WASI_SOURCES_BUILDER

ENV HOST_ARCH=wasm32 \
    HOST_CPU=wasm32 \
    HOST_KERNEL=unknown \
    HOST_OS=wasi \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=wasm32

ENV HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_ARCH}/sysroot \
    SYSTEM_NAME=Wasi

COPY ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-wasi \
     ${PACKAGE_BASE_NAME}-platform-sdk-wasi-compiler-deps \
     ${PACKAGE_BASE_NAME}-platform-sdk-wasi-libc \
     /sources/

# webassembly libc
FROM WASI_SOURCES_BUILDER AS WASI_LIBC_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-wasi-compiler-deps

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
