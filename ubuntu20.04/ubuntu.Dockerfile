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

ENV BUILD_KERNEL=${BUILD_KERNEL}
ENV BUILD_OS=${BUILD_OS}
ENV BUILD_PROCESSOR=${BUILD_PROCESSOR}
ENV DEB_PATH=${DEB_PATH}
ENV HOST_KERNEL=${HOST_KERNEL}
ENV HOST_OS=${HOST_OS}
ENV HOST_PROCESSOR=${HOST_PROCESSOR}
ENV PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME}
ENV PACKAGE_ROOT=${PACKAGE_ROOT}

ENV DEBIAN_FRONTEND=noninteractive
ENV BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}
ENV HOST_TRIPLE_SHORTENED=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}
ENV HOST_TRIPLE=${HOST_TRIPLE_SHORTENED}
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}

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
COPY ${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-cmake \
     ${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-configure \
     ${PACKAGE_BASE_NAME}-platform-sdk-configure \
     ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang \
     ${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tool \
     ${PACKAGE_ROOT}/bin/

RUN chmod +x ${PACKAGE_ROOT}/bin/${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-cmake \
             ${PACKAGE_ROOT}/bin/${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-cmake \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
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

# llvm bootstrap build
FROM BASE AS LLVM_BOOTSTRAP_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap

# LTO configuration: OFF or Full
# Set to full for prod
ENV ENABLE_FLTO=OFF

# llvm build
FROM LLVM_BOOTSTRAP_BUILDER AS LLVM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project

# icu build
FROM LLVM_BUILDER AS ICU_BUILDER

COPY icu-uconfig-prepend.h .

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-icu4c

# cmark build
FROM ICU_BUILDER AS CMARK_BUILDER

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

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}-${HOST_PROCESSOR}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}-${HOST_PROCESSOR}.deb

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

# android-ndk package
FROM PYTHONKIT_BUILDER AS ANDROID_NDK_BUILDER

ENV ANDROID_NDK_VERSION=r21d

RUN export SOURCE_PACKAGE_NAME=android-ndk \
    && export SOURCE_PACKAGE_VERSION=${ANDROID_NDK_VERSION} \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && mkdir ${SOURCE_ROOT}

COPY android-ndk-linux-time-h.diff /sources/android-ndk-${ANDROID_NDK_VERSION}

COPY ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime \
     ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-builder-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross \
     /sources/

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk

# android environment
ENV HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot/usr

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

# xz build
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

# foundation build
FROM ANDROID_LIBDISPATCH_BUILDER AS ANDROID_FOUNDATION_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation-cross

# xctest build
FROM ANDROID_FOUNDATION_BUILDER AS ANDROID_XCTEST_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest-cross \
    && dpkg -i /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \
               /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb


# llbuild build
FROM ANDROID_XCTEST_BUILDER AS ANDROID_LLBUILD_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild-android

# swift-tools-support-core build
FROM ANDROID_LLBUILD_BUILDER AS ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core-builder-android

# android yams build
FROM ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER AS ANDROID_YAMS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross

# android swift-driver build
FROM ANDROID_YAMS_BUILDER AS ANDROID_SWIFT_DRIVER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross

# android swiftpm build
FROM ANDROID_SWIFT_DRIVER AS ANDROID_SWIFTPM_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross

# android swift-syntax build
FROM ANDROID_SWIFTPM_BUILDER AS ANDROID_SWIFT_SYNTAX_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross

# android swift-format build
FROM ANDROID_SWIFT_SYNTAX_BUILDER AS ANDROID_SWIFT_FORMAT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross

# android swift-doc build
FROM ANDROID_SWIFT_FORMAT_BUILDER AS ANDROID_SWIFT_DOC_BUILDER

#RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android

# android pythonkit build
FROM ANDROID_SWIFT_DOC_BUILDER AS ANDROID_PYTHONKIT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross

# sources step
FROM ANDROID_PYTHONKIT_BUILDER AS WINDOWS_SOURCES_BUILDER

# mingw-w64 source
RUN export SOURCE_PACKAGE_NAME=mingw-w64 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && git clone https://github.com/mirror/mingw-w64.git --single-branch --branch master ${SOURCE_ROOT}

# gcc source
RUN export SOURCE_PACKAGE_NAME=gcc \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && git clone https://github.com/gcc-mirror/gcc.git --single-branch --branch master ${SOURCE_ROOT}

# windows environment
ENV HOST_KERNEL=w64 \
    HOST_OS=mingw32 \
    HOST_OS_API_LEVEL= \
    HOST_PROCESSOR=x86_64

ENV TARGET_PROCESSOR=${HOST_PROCESSOR} \
    TARGET_KERNEL=w64 \
    TARGET_OS=mingw32

ENV PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
    SYSTEM_NAME=Windows

# windows mingw-headers build
FROM WINDOWS_SOURCES_BUILDER AS WINDOWS_MINGW_HEADERS_BUILDER

RUN export SOURCE_PACKAGE_NAME=mingw-w64-headers \
    && export SOURCE_ROOT=/sources/mingw-w64/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --enable-crt \
           --enable-sdk=all \
           --prefix=${STAGE_ROOT}/install${PACKAGE_PREFIX} \
           --with-default-win32-winnt=0x0A00 \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && ln -sf . \
              install${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot/mingw \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *.deb ${SOURCE_PACKAGE_NAME}.deb \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# windows mingw-crt build
FROM WINDOWS_MINGW_HEADERS_BUILDER AS WINDOWS_MINGW_CRT_BUILDER

RUN export SOURCE_PACKAGE_NAME=mingw-w64-crt \
    && export SOURCE_ROOT=/sources/mingw-w64/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-lib32 \
           --enable-experimental=registeredprintf,softmath \
           --enable-warnings=0 \
           --prefix=${STAGE_ROOT}/install${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *.deb ${SOURCE_PACKAGE_NAME}.deb \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# windows gcc build
FROM WINDOWS_MINGW_CRT_BUILDER AS WINDOWS_LIBGCC_BUILDER

RUN export SOURCE_PACKAGE_NAME=libgcc \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-configure \
           /sources/gcc/configure \
           --disable-bootstrap \
           --disable-gomp \
           --disable-libssp \
           --disable-multilib \
           --disable-werror \
           --enable-languages=c \
           --prefix=${STAGE_ROOT}/install${PACKAGE_PREFIX} \
           --target=${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS} \
           --with-build-sysroot=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
           --with-native-system-header-dir=/include \
           --with-sysroot=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
           AR_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-ar \
           AS_FOR_TARGET=/usr/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-as \
           CC_FOR_TARGET=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
           CPP_FOR_TARGET="${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang -E" \
           CXX_FOR_TARGET=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++ \
           DLLTOOL_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-dlltool \
           GCC_FOR_TARGET=${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
           LIPO_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-lipo \
           LD_FOR_TARGET="/${PACKAGE_ROOT}/bin/ld.lld /force:multiple" \
           NM_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-nm \
           OBJCOPY_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-objcopy \
           OBJDUMP_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-objdump \
           RANLIB_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-ranlib \
           READELF_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-readelf \
           RC_FOR_TARGET=/usr/bin/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}-windres \
           SIZE_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-size \
           STRIP_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-strip \
           STRINGS_FOR_TARGET=${PACKAGE_ROOT}/bin/llvm-strings \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} all-target-libatomic all-target-libgcc \
    && make -j${NUM_PROCESSORS} install-target-libatomic install-target-libgcc \
    && mv install${PACKAGE_PREFIX}/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}/lib/lib* \
          install${PACKAGE_PREFIX}/lib \
    && mv install${PACKAGE_PREFIX}/lib/gcc/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}/11.0.0/include \
          install${PACKAGE_PREFIX}/include \
    && mv install${PACKAGE_PREFIX}/lib/gcc/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS}/11.0.0/lib* \
          install${PACKAGE_PREFIX}/lib \
    && rm -rf install${PACKAGE_PREFIX}/${TARGET_PROCESSOR}-${TARGET_KERNEL}-${TARGET_OS} \
              install${PACKAGE_PREFIX}/lib/gcc \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *.deb ${SOURCE_PACKAGE_NAME}.deb \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android compiler-rt build (for host)
FROM WINDOWS_LIBGCC_BUILDER AS WINDOWS_COMPILER_RT_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-compiler-rt

# android libunwind build
FROM WINDOWS_COMPILER_RT_BUILDER AS WINDOWS_LIBUNWIND_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-libunwind-cross

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
