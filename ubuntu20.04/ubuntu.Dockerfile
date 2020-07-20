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

ENV BUILD_KERNEL=${BUILD_KERNEL} \
    BUILD_OS=${BUILD_OS} \
    BUILD_PROCESSOR=${BUILD_PROCESSOR} \
    DEB_PATH=${DEB_PATH} \
    HOST_KERNEL=${HOST_KERNEL} \
    HOST_OS=${HOST_OS} \
    HOST_PROCESSOR=${HOST_PROCESSOR} \
    PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME} \
    PACKAGE_ROOT=${PACKAGE_ROOT} \
    SYSROOT=/

ENV ARCH_FLAGS="-march=haswell -mtune=haswell" \
    BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
    HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}

ENV LD_LIBRARY_PATH=${PACKAGE_ROOT}/lib

# swift build config
ENV SWIFTPM_BUILD_ARGS="\
    -Xcc -Oz \
    -Xcxx -Oz \
    -Xlinker -s \
    -Xlinker -O2 \
    -Xswiftc -whole-module-optimization \
    -Xswiftc -Osize \
    --configuration release \
    --enable-test-discovery"

# platform sdk tool wrapper scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-configure \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
     ${PACKAGE_BASE_NAME}-platform-sdk-ml64 \
     ${PACKAGE_BASE_NAME}-platform-sdk-mslink \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tool \
     ${PACKAGE_ROOT}/bin/

RUN chmod +x ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-cmake \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-swift-tool

COPY ${PACKAGE_BASE_NAME}-platform-sdk-make-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-install \
     /sources/

# platform sdk package build scripts
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk \
     ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c \
     ${PACKAGE_BASE_NAME}-platform-sdk-jwasm \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap \
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
     ${PACKAGE_BASE_NAME}-platform-sdk-yams \
     /sources/

# LTO configuration: OFF or Full
# Set to full for prod
ENV ENABLE_FLTO=OFF

# llvm bootstrap build
FROM BASE AS LLVM_BOOTSTRAP_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap

# llvm build
FROM LLVM_BOOTSTRAP_BUILDER AS LLVM_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project

# icu build
FROM LLVM_BUILDER AS ICU_BUILDER

COPY icu-uconfig-prepend.h .

RUN export LDFLAGS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c

# cmark build
FROM ICU_BUILDER AS CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark

# swift build
FROM CMARK_BUILDER AS SWIFT_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift

# lldb build
FROM SWIFT_BUILDER AS LLDB_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb

# libdispatch build
FROM LLDB_BUILDER AS LIBDISPATCH_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch

# foundation build
FROM LIBDISPATCH_BUILDER AS FOUNDATION_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation

# xctest build
FROM FOUNDATION_BUILDER AS XCTEST_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}-${HOST_PROCESSOR}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}-${HOST_PROCESSOR}.deb

# llbuild build
FROM XCTEST_BUILDER AS LLBUILD_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild

# swift-tools-support-core build
FROM LLBUILD_BUILDER AS SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core

# yams build
FROM SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS YAMS_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-yams

# swift-driver build
FROM YAMS_BUILDER AS SWIFT_DRIVER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver

# swiftpm build
FROM SWIFT_DRIVER AS SWIFTPM_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager

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
COPY ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libgcc-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross \
     /sources/

# android package builders
COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-builder-android \
     /sources/

# android environment
ENV HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64

ENV TARGET_KERNEL=${HOST_KERNEL} \
    TARGET_OS=${HOST_OS} \
    TARGET_OS_API_LEVEL=${HOST_OS_API_LEVEL} \
    TARGET_PROCESSOR=${HOST_PROCESSOR}

ENV ARCH_FLAGS="-march=armv8-a -mtune=cortex-a57" \
    HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot/usr \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot

# android ndk headers build
FROM ANDROID_NDK_BUILDER AS ANDROID_NDK_HEADERS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers

# android ndk runtime build
FROM ANDROID_NDK_HEADERS_BUILDER AS ANDROID_NDK_RUNTIME_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime

# android libgcc build
FROM ANDROID_NDK_RUNTIME_BUILDER AS ANDROID_LIBGCC_BUILDER

# RUN export ARCH_FLAGS="-march=haswell -mtune=haswell" \
#            AS_FOR_TARGET="${PACKAGE_ROOT}/bin/clang --target=${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}${TARGET_OS_API_LEVEL}" \
#            LD_FOR_TARGET=${PACKAGE_ROOT}/bin/clang \
#            LDFLAGS_FOR_TARGET="-rtlib=libgcc --target=${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}${TARGET_OS_API_LEVEL}" \
#            HOST_KERNEL=${BUILD_KERNEL} \
#            HOST_OS=${BUILD_OS} \
#            HOST_OS_API_LEVEL= \
#            HOST_PROCESSOR=${BUILD_PROCESSOR} \
#            SYSROOT=/ \
#            TARGET_ARCH_FLAGS="${ARCH_FLAGS}" \
#     && export BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
#               HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
#     && bash ${PACKAGE_BASE_NAME}-platform-sdk-libgcc-cross

# android compiler-rt build (for host)
FROM ANDROID_LIBGCC_BUILDER AS ANDROID_COMPILER_RT_BUILDER

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
FROM ANDROID_XZ_BUILDER AS ANDROID_XML_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross

# android libuuid build
FROM ANDROID_XML_BUILDER AS ANDROID_UUID_BUILDER

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

# android curl build
FROM ANDROID_OPENSSL_BUILDER AS ANDROID_CURL_BUILDER

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

# android llvm build
FROM ANDROID_Z3_BUILDER AS ANDROID_LLVM_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android

# android cmark build
FROM ANDROID_LLVM_BUILDER AS ANDROID_CMARK_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross

# android swift build
FROM ANDROID_CMARK_BUILDER AS ANDROID_SWIFT_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-android

# android lldb build
FROM ANDROID_SWIFT_BUILDER AS ANDROID_LLDB_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-cross

# android libdispatch build
FROM ANDROID_LLDB_BUILDER AS ANDROID_LIBDISPATCH_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross

# android foundation build
FROM ANDROID_LIBDISPATCH_BUILDER AS ANDROID_FOUNDATION_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross

# android xctest build
FROM ANDROID_FOUNDATION_BUILDER AS ANDROID_XCTEST_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
    && dpkg -i /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb

# android llbuild build
FROM ANDROID_XCTEST_BUILDER AS ANDROID_LLBUILD_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android

# android swift-tools-support-core build
FROM ANDROID_LLBUILD_BUILDER AS ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-builder-android

# android yams build
FROM ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS ANDROID_YAMS_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross

# android swift-driver build
FROM ANDROID_YAMS_BUILDER AS ANDROID_SWIFT_DRIVER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross

# android swiftpm build
FROM ANDROID_SWIFT_DRIVER AS ANDROID_SWIFTPM_BUILDER

RUN export LIBS="-lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross

# android swift-syntax build
FROM ANDROID_SWIFTPM_BUILDER AS ANDROID_SWIFT_SYNTAX_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross

# android swift-format build
FROM ANDROID_SWIFT_SYNTAX_BUILDER AS ANDROID_SWIFT_FORMAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross

# android swift-doc build
FROM ANDROID_SWIFT_FORMAT_BUILDER AS ANDROID_SWIFT_DOC_BUILDER

# RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android

# android pythonkit build
FROM ANDROID_SWIFT_DOC_BUILDER AS ANDROID_PYTHONKIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross

# windows environment
FROM ANDROID_PYTHONKIT_BUILDER AS WINDOWS_SOURCES_BUILDER

ENV HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64

ENV TARGET_PROCESSOR=${HOST_PROCESSOR} \
    TARGET_KERNEL=${HOST_KERNEL} \
    TARGET_OS=${HOST_OS} \
    TARGET_OS_API_LEVEL=${HOST_OS_API_LEVEL}

ENV ARCH_FLAGS="-march=haswell -mtune=haswell" \
    HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
    SYSROOT=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
    SYSTEM_NAME=Windows

COPY ${PACKAGE_BASE_NAME}-platform-sdk-binutils \
     ${PACKAGE_BASE_NAME}-platform-sdk-gcc \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-crt \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-windows \
     ${PACKAGE_BASE_NAME}-platform-sdk-wineditline-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross \
     /sources/

COPY mingw-sdk.modulemap \
     /sources/

# mingw-w64 source
RUN export SOURCE_PACKAGE_NAME=mingw-w64 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && git clone https://github.com/val-verde/mingw-w64.git --single-branch --branch master ${SOURCE_ROOT}

# windows mingw-headers build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_MINGW_HEADERS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-headers

# windows mingw-crt build
FROM WINDOWS_MINGW_HEADERS_BUILDER AS WINDOWS_MINGW_CRT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-mingw-w64-crt

# windows binutils (host)
FROM WINDOWS_MINGW_CRT_BUILDER AS WINDOWS_BINUTILS_HOST_BUILDER

RUN export ARCH_FLAGS="-march=haswell -mtune=haswell" \
           HOST_KERNEL=${BUILD_KERNEL} \
           HOST_OS=${BUILD_OS} \
           HOST_OS_API_LEVEL= \
           HOST_PROCESSOR=${BUILD_PROCESSOR} \
           SYSROOT=/ \
           TARGET_ARCH_FLAGS="${ARCH_FLAGS}" \
    && export BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
              HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-binutils

# windows gcc (host)
FROM WINDOWS_BINUTILS_HOST_BUILDER AS WINDOWS_GCC_HOST_BUILDER

RUN export ARCH_FLAGS="-march=haswell -mtune=haswell" \
           AS_FOR_TARGET=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-as \
           HOST_KERNEL=${BUILD_KERNEL} \
           HOST_OS=${BUILD_OS} \
           HOST_OS_API_LEVEL= \
           HOST_PROCESSOR=${BUILD_PROCESSOR} \
           LDFLAGS_FOR_TARGET="-Wl,/force:multiple" \
           RC_FOR_TARGET=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-windres \
           SYSROOT=/ \
           TARGET_ARCH_FLAGS="${ARCH_FLAGS}" \
    && export BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
              HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-gcc

# windows libgcc build
FROM WINDOWS_GCC_HOST_BUILDER AS WINDOWS_LIBGCC_BUILDER

RUN export ARCH_FLAGS="-march=haswell -mtune=haswell" \
           AS_FOR_TARGET=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-as \
           HOST_KERNEL=${BUILD_KERNEL} \
           HOST_OS=${BUILD_OS} \
           HOST_OS_API_LEVEL= \
           HOST_PROCESSOR=${BUILD_PROCESSOR} \
           LDFLAGS_FOR_TARGET="-Wl,/force:multiple" \
           RC_FOR_TARGET=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-windres \
           SYSROOT=/ \
           TARGET_ARCH_FLAGS="${ARCH_FLAGS}" \
    && export BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS} \
              HOST_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-libgcc-cross

# windows compiler-rt build (for host)
FROM WINDOWS_LIBGCC_BUILDER AS WINDOWS_COMPILER_RT_BUILDER

RUN export CLANG_RT_LIB=clang_rt.builtins-${HOST_PROCESSOR} \
           SDK=windows \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt

# windows mingw-winpthreads build
FROM WINDOWS_COMPILER_RT_BUILDER AS WINDOWS_MINGW_WINPTHREADS_BUILDER

RUN export RC=${PACKAGE_ROOT}/bin/x86_64-w64-mingw32-windres \
           RCFLAGS="--preprocessor-arg=--sysroot=${PACKAGE_PREFIX}" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-winpthreads-cross

# windows libunwind build
FROM WINDOWS_MINGW_WINPTHREADS_BUILDER AS WINDOWS_LIBUNWIND_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross

# windows libcxxabi build
FROM WINDOWS_LIBUNWIND_BUILDER AS WINDOWS_LIBCXXABI_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxxabi-windows

# windows libcxx build
FROM WINDOWS_LIBCXXABI_BUILDER AS WINDOWS_LIBCXX_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-libcxx-windows

# windows icu build
FROM WINDOWS_LIBCXX_BUILDER AS WINDOWS_ICU_BUILDER

RUN export LDFLAGS="-fuse-ld=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-mslink" \
           LIBS="-lc++abi -lucrt -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross

# windows xz build
FROM WINDOWS_ICU_BUILDER AS WINDOWS_XZ_BUILDER

RUN export RC=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-windres \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross

# windows zlib build
FROM WINDOWS_XZ_BUILDER AS WINDOWS_ZLIB_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-zlib-cross

# windows libxml2 build
FROM WINDOWS_ZLIB_BUILDER AS WINDOWS_XML_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross

# android ncurses build
FROM WINDOWS_XML_BUILDER AS WINDOWS_NCURSES_BUILDER

RUN export LDFLAGS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross

# windows editline build
FROM WINDOWS_NCURSES_BUILDER AS WINDOWS_WINEDITLINE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-wineditline-cross

# windows sqlite3 build
FROM WINDOWS_WINEDITLINE_BUILDER AS WINDOWS_SQLITE3_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross

# windows openssl build
FROM WINDOWS_SQLITE3_BUILDER AS WINDOWS_OPENSSL_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-openssl-windows

# windows curl build
FROM WINDOWS_OPENSSL_BUILDER AS WINDOWS_CURL_BUILDER

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

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross

FROM WINDOWS_Z3_BUILDER AS WINDOWS_JWASM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-jwasm

# windows llvm build
FROM WINDOWS_JWASM_BUILDER AS WINDOWS_LLVM_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
           RC=${PACKAGE_ROOT}/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-windres \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-windows

# windows cmark build
FROM WINDOWS_LLVM_BUILDER AS WINDOWS_CMARK_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross

# windows swift build
FROM WINDOWS_CMARK_BUILDER AS WINDOWS_SWIFT_BUILDER

RUN export LIBS="-lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-windows

# windows lldb build
FROM WINDOWS_SWIFT_BUILDER AS WINDOWS_LLDB_BUILDER

RUN export LIBS="-lpsapi -lc++abi -lunwind" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-windows

# windows libdispatch build
FROM WINDOWS_LLDB_BUILDER AS WINDOWS_LIBDISPATCH_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-windows

# windows foundation build
FROM WINDOWS_LIBDISPATCH_BUILDER AS WINDOWS_FOUNDATION_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2 \
                   -Wno-implicit-int-float-conversion \
                   -Wno-nonnull \
                   -Wno-pointer-sign \
                   -Wno-switch" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-windows || true

# windows xctest build
FROM WINDOWS_FOUNDATION_BUILDER AS WINDOWS_XCTEST_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-windows
RUN dpkg -i /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb

# HACK: Enable these when Windows Foundation is built.
# /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \

RUN cp /sources/build-staging/swift-corelibs-foundation-mingw32-x86_64/Sources/Foundation/lib*.dll \
       ${SYSROOT}/lib/swift/windows/ \
    && cp /sources/build-staging/swift-corelibs-foundation-mingw32-x86_64/Sources/Foundation/lib*.a \
          ${SYSROOT}/lib/swift/windows/ \
    && cp /sources/build-staging/swift-corelibs-foundation-mingw32-x86_64/CoreFoundation/lib*.a \
          ${SYSROOT}/lib/swift/windows/ \
    && cp /sources/build-staging/swift-corelibs-foundation-mingw32-x86_64/swift/*.swift* \
          ${SYSROOT}/lib/swift/windows/${HOST_PROCESSOR} \
    && cp -r ${PACKAGE_ROOT}/lib/swift/CoreFoundation ${SYSROOT}/lib/swift

# windows llbuild build
FROM WINDOWS_XCTEST_BUILDER AS WINDOWS_LLBUILD_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2 -I/sources/swift-llbuild/lib/llvm/Support" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-cross || true

# windows swift-tools-support-core build
FROM WINDOWS_LLBUILD_BUILDER AS WINDOWS_SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2 -I/sources/swift-llbuild/lib/llvm/Support" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-builder-android || true

# windows yams build
FROM WINDOWS_SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS WINDOWS_YAMS_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2 -I/sources/swift-llbuild/lib/llvm/Support" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross || true

# windows swift-driver build
FROM WINDOWS_YAMS_BUILDER AS WINDOWS_SWIFT_DRIVER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2 -I/sources/swift-llbuild/lib/llvm/Support" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross || true

# windows swiftpm build
FROM WINDOWS_SWIFT_DRIVER AS WINDOWS_SWIFTPM_BUILDER

RUN export CFLAGS="-fms-extensions -fms-compatibility-version=19.2" \
           CXXFLAGS="-fms-extensions -fms-compatibility-version=19.2 -I/sources/swift-llbuild/lib/llvm/Support" \
           LIBS="-lc++abi -lunwind" \
           SWIFTCFLAGS="-use-ld=${PACKAGE_ROOT}/bin/val-verde-platform-sdk-mslink \
                        -L${SYSROOT}/lib" \
    && bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross || true

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
