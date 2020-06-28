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
    ${PACKAGE_ROOT}/bin/

RUN chmod +x ${PACKAGE_ROOT}/bin/${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-cmake \
             ${PACKAGE_ROOT}/bin/${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-configure \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-cmake \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang \
             ${PACKAGE_ROOT}/bin/${PACKAGE_BASE_NAME}-platform-sdk-clang++

COPY ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
     ${PACKAGE_BASE_NAME}-platform-sdk-ninja-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-build \
     ${PACKAGE_BASE_NAME}-platform-sdk-package-install \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb \ 
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c \ 
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit /sources/

# llvm bootstrap build
FROM BASE AS LLVM_BOOTSTRAP_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap

# LTO configuration: OFF or Full
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

RUN export ANDROID_NDK_URL=https://dl.google.com/android/repository \
    && export SOURCE_PACKAGE_NAME=android-ndk \
    && export SOURCE_PACKAGE_VERSION=${ANDROID_NDK_VERSION} \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME} \
    && cd ${SOURCE_ROOT} \
    && wget -c ${ANDROID_NDK_URL}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}-${BUILD_KERNEL}-${BUILD_PROCESSOR}.zip \
    && unzip ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}-${BUILD_KERNEL}-${BUILD_PROCESSOR}.zip \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && mkdir -p install/${PACKAGE_ROOT} \
    && mv ${SOURCE_ROOT}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} install/${PACKAGE_ROOT} \
    && patch -i ${SOURCE_ROOT}/android-ndk-linux-time-h.diff \
                ${STAGE_ROOT}/install/${PACKAGE_ROOT}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}/sysroot/usr/include/linux/time.h \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${BUILD_OS}-${BUILD_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android environment
ENV HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot/usr

# android ndk headers build
FROM ANDROID_NDK_BUILDER AS ANDROID_NDK_HEADERS_BUILDER

RUN mkdir -p /sources/ndk-headers \
    && export SOURCE_PACKAGE_NAME=ndk-headers \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT}/install/${PACKAGE_PREFIX}/include \
    && export TOOLCHAIN_ROOT=${PACKAGE_ROOT}/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/${BUILD_KERNEL}-${BUILD_PROCESSOR} \
    && export SYSROOT=${TOOLCHAIN_ROOT}/sysroot \
    && rsync -aPx ${SYSROOT}/usr/include/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
                  ${SYSROOT}/usr/include/*.h \
                  ${SYSROOT}/usr/include/android \
                  ${SYSROOT}/usr/include/arpa \
                  ${SYSROOT}/usr/include/asm-generic \
                  ${SYSROOT}/usr/include/bits \
                  ${SYSROOT}/usr/include/c++ \
                  ${SYSROOT}/usr/include/linux \
                  ${SYSROOT}/usr/include/net \
                  ${SYSROOT}/usr/include/netinet \
                  ${SYSROOT}/usr/include/sys \
                  ${STAGE_ROOT}/install/${PACKAGE_PREFIX}/include \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android ndk runtime build
FROM ANDROID_NDK_HEADERS_BUILDER AS ANDROID_NDK_RUNTIME_BUILDER

RUN export SOURCE_PACKAGE_NAME=ndk-runtime \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT}/install/${PACKAGE_PREFIX}/include \
    && export TOOLCHAIN_ROOT=${PACKAGE_ROOT}/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/${BUILD_KERNEL}-${BUILD_PROCESSOR} \
    && export SYSROOT=${TOOLCHAIN_ROOT}/sysroot \
    && rsync -aPx ${SYSROOT}/usr/lib/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}/*.so \
                  ${SYSROOT}/usr/lib/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}/${HOST_OS_API_LEVEL}/* \
                  ${TOOLCHAIN_ROOT}/lib/gcc/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}/4.9.x/*.a \
                  ${TOOLCHAIN_ROOT}/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}/lib64/*.a \
                  ${STAGE_ROOT}/install/${PACKAGE_PREFIX}/lib \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android icu build
FROM ANDROID_NDK_RUNTIME_BUILDER AS ANDROID_ICU_BUILDER

RUN export SOURCE_PACKAGE_NAME=icu4c \
    && export SOURCE_PACKAGE_VERSION=67_1 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd ${SOURCE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/source/configure \
           --disable-extras \
           --disable-samples \
           --disable-static \
           --disable-tests \
           --disable-tools \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           --with-cross-build=/sources/build-staging/${SOURCE_PACKAGE_NAME} \
           --with-library-suffix=swift \
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

# xz build
FROM ANDROID_ICU_BUILDER AS ANDROID_XZ_BUILDER

RUN export SOURCE_PACKAGE_NAME=xz \
    && export SOURCE_PACKAGE_VERSION=5.2.5 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://tukaani.org/${SOURCE_PACKAGE_NAME}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libxml2 build
FROM ANDROID_XZ_BUILDER AS ANDROID_XML_BUILDER

RUN export SOURCE_PACKAGE_NAME=libxml2 \
    && export SOURCE_PACKAGE_VERSION=2.9.10 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c http://xmlsoft.org/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && CFLAGS="-I${PACKAGE_PREFIX}/include" \
       ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           --with-icu \
           --without-python \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libuuid build
FROM ANDROID_XML_BUILDER AS ANDROID_UUID_BUILDER

RUN export SOURCE_PACKAGE_NAME=libuuid \
    && export SOURCE_PACKAGE_VERSION=1.0.3 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://sourceforge.net/projects/libuuid/files/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz/download \
    && mv download ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android ncurses build
FROM ANDROID_UUID_BUILDER AS ANDROID_NCURSES_BUILDER

RUN export SOURCE_PACKAGE_NAME=ncurses \
    && export SOURCE_PACKAGE_VERSION=6.2 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz \
    && rm -rf ${STAGE_ROOT}/* \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && cd ${STAGE_ROOT} \
    && OPTIMIZATION_LEVEL=3 \
       ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --enable-ext-colors \
           --enable-mixed-case \
           --enable-pc-files \
           --enable-rpath \
           --prefix=${PACKAGE_PREFIX} \
           --with-curses-h \
           --with-cxx \
           --with-cxx-shared \
           --with-install-prefix=${STAGE_ROOT}/install \
           --with-pkg-config=/usr/bin/pkg-config \
           --with-pkg-config-libdir=${PACKAGE_PREFIX}/lib/pkgconfig \
           --with-shared \
           --with-termlib \
           --with-ticlib \
           --with-tic-path=/usr/bin/tic \
           --without-debug \
           --without-manpages \
           --without-progs \
           --without-tack \
           --without-tests \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libedit build
FROM ANDROID_NCURSES_BUILDER AS ANDROID_LIBEDIT_BUILDER

RUN export SOURCE_PACKAGE_NAME=libedit \
    && export SOURCE_PACKAGE_VERSION=20191231-3.1 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://www.thrysoee.dk/editline/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && cd ${STAGE_ROOT} \
    && CFLAGS="-I${PACKAGE_PREFIX}/include -I${PACKAGE_PREFIX}/include/ncurses -D__STDC_ISO_10646__=201103L -DNBBY=CHAR_BIT" \
       LDFLAGS="-L${PACKAGE_PREFIX}/lib" \
       ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android sqlite3 build
FROM ANDROID_LIBEDIT_BUILDER AS ANDROID_SQLITE3_BUILDER

RUN export SOURCE_PACKAGE_NAME=sqlite \
    && export SOURCE_PACKAGE_VERSION=autoconf-3310100 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://sqlite.org/2020/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android openssl build
FROM ANDROID_SQLITE3_BUILDER AS ANDROID_OPENSSL_BUILDER

RUN export SOURCE_PACKAGE_NAME=openssl \
    && export SOURCE_PACKAGE_VERSION=1.1.1g \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://www.openssl.org/source/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && export ANDROID_NDK_HOME=${PACKAGE_ROOT}/android-ndk-${ANDROID_NDK_VERSION} \
    && export PATH=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${BUILD_KERNEL}-${BUILD_PROCESSOR}/bin:${PATH} \
    && ${SOURCE_ROOT}/Configure \
           ${HOST_OS}-arm64 \
           -D__ANDROID_API__=${HOST_OS_API_LEVEL} \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           --openssldir=etc/ssl \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install_sw \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android curl build
FROM ANDROID_OPENSSL_BUILDER AS ANDROID_CURL_BUILDER

RUN export SOURCE_PACKAGE_NAME=curl \
    && export SOURCE_PACKAGE_VERSION=7.70.0 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://curl.haxx.se/download/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-doc \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           --with-ssl=${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libexpat build
FROM ANDROID_CURL_BUILDER AS ANDROID_LIBEXPAT_BUILDER

RUN export SOURCE_PACKAGE_NAME=expat \
    && export SOURCE_PACKAGE_VERSION=2.2.9 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://github.com/libexpat/libexpat/releases/download/R_2_2_9/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libffi build
FROM ANDROID_LIBEXPAT_BUILDER AS ANDROID_LIBFFI_BUILDER

RUN export SOURCE_PACKAGE_NAME=libffi \
    && export SOURCE_PACKAGE_VERSION=3.3 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd /sources \
    && wget -c https://gcc.gnu.org/pub/${SOURCE_PACKAGE_NAME}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-configure \
           ${SOURCE_ROOT}/configure \
           --disable-static \
           --enable-shared \
           --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android z3 build
FROM ANDROID_LIBFFI_BUILDER AS ANDROID_Z3_BUILDER

RUN export SOURCE_PACKAGE_NAME=z3 \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && git clone https://github.com/Z3Prover/${SOURCE_PACKAGE_NAME}.git --single-branch --branch master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android llvm build
FROM ANDROID_Z3_BUILDER AS ANDROID_LLVM_BUILDER

RUN export SOURCE_PACKAGE_NAME=llvm-project \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd ${SOURCE_ROOT} \
    && git remote set-branches --add origin dutch-android-master \
    && git fetch origin dutch-android-master \
    && git checkout dutch-android-master \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DBUILD_SHARED_LIBS=TRUE \
           -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
           -DCLANG_INCLUDE_DOCS=FALSE \
           -DCLANG_INCLUDE_TESTS=FALSE \
           -DCLANG_LINK_CLANG_DYLIB=FALSE \
           -DCLANG_TABLEGEN=/sources/build-staging/llvm-project/bin/clang-tblgen \
           -DCLANG_TOOL_ARCMT_TEST_BUILD=FALSE \
           -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=FALSE \
           -DCLANG_TOOL_CLANG_REFACTOR_TEST_BUILD=FALSE \
           -DCLANG_TOOL_C_ARCMT_TEST_BUILD=FALSE \
           -DCLANG_TOOL_C_INDEX_TEST_BUILD=FALSE \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCOMPILER_RT_CAN_EXECUTE_TESTS=FALSE \
           -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
           -DHAVE_CXX_ATOMICS_WITH_LIB=TRUE \
           -DHAVE_CXX_ATOMICS64_WITH_LIB=TRUE \
           -DHAVE_GNU_POSIX_REGEX=TRUE \
           -DHAVE_INOTIFY=TRUE \
           -DHAVE_THREAD_SAFETY_ATTRIBUTES=TRUE \
           -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=FALSE \
           -DLIBCXX_ENABLE_SHARED=TRUE \
           -DLIBCXX_ENABLE_STATIC=FALSE \
           -DLIBOMPTARGET_DEP_LIBFFI_INCLUDE_DIR:PATH=/usr/include/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
           -DLIBOMPTARGET_NVPTX_ALTERNATE_HOST_COMPILER=gcc-8 \
           -DLLD_INCLUDE_TESTS=FALSE \
           -DLLVM_BUILD_EXAMPLES=FALSE \
           -DLLVM_BUILD_DOCS=FALSE \
           -DLLVM_BUILD_LLVM_DYLIB=FALSE \
           -DLLVM_BUILD_TESTS=FALSE \
           -DLLVM_BUILD_UTILS=TRUE \
           -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_PROCESSOR}-unknown-${HOST_KERNEL}-${HOST_OS} \
           -DLLVM_ENABLE_LIBCXX=TRUE \
           -DLLVM_ENABLE_LLD=TRUE \
           -DLLVM_ENABLE_LTO=${ENABLE_FLTO} \
           -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;libclc;lld;openmp;parallel-libs;polly;pstl" \
           -DLLVM_ENABLE_UNWIND_TABLES=FALSE \
           -DLLVM_ENABLE_Z3_SOLVER=TRUE \
           -DLLVM_HOST_TRIPLE=${HOST_PROCESSOR}-unknown-${HOST_KERNEL}-${HOST_OS} \
           -DLLVM_INCLUDE_DOCS=FALSE \
           -DLLVM_INCLUDE_EXAMPLES=FALSE \
           -DLLVM_INCLUDE_GO_TESTS=FALSE \
           -DLLVM_INCLUDE_TESTS=FALSE \
           -DLLVM_INCLUDE_UTILS=TRUE \
           -DLLVM_LINK_LLVM_DYLIB=FALSE \
           -DLLVM_OPTIMIZED_TABLEGEN=TRUE \
           -DLLVM_POLLY_LINK_INTO_TOOLS=TRUE \
           -DLLVM_TABLEGEN=/sources/build-staging/llvm-project/bin/llvm-tblgen \
           -DLLVM_TARGETS_TO_BUILD=all \
           -DLLVM_TOOL_LLVM_C_TEST_BUILD=FALSE \
           -DLLVM_USE_HOST_TOOLS=TRUE \
           -DLLVM_USE_NEWPM=TRUE \
           -DLLVM_Z3_INSTALL_DIR=${PACKAGE_PREFIX} \
           -DMLIR_TABLEGEN=/sources/build-staging/llvm-project/bin/mlir-tblgen \
           ${SOURCE_ROOT}/llvm \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb

# android cmark build
FROM ANDROID_LLVM_BUILDER AS ANDROID_CMARK_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-cmark \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS}

# android swift build
FROM ANDROID_CMARK_BUILDER AS ANDROID_SWIFT_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd ${SOURCE_ROOT} \
    && git remote set-branches --add origin dutch-android-master \
    && git fetch origin dutch-android-master \
    && git checkout dutch-android-master \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DClang_DIR=/sources/build-staging/llvm-project-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/clang \
           -DICU_I18N_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
           -DICU_I18N_LIBRARIES=${PACKAGE_PREFIX}/lib/libicui18nswift.so \
           -DICU_UC_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
           -DICU_UC_LIBRARIES=${PACKAGE_PREFIX}/lib/libicuucswift.so \
           -DLibEdit_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
           -DLibEdit_LIBRARIES=${PACKAGE_PREFIX}/lib/libedit.so \
           -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
           -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
           -DLLVM_BUILD_LIBRARY_DIR=/sources/build-staging/llvm-project-${HOST_OS}-${HOST_PROCESSOR}/lib \
           -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
           -DLLVM_ENABLE_LIBCXX=TRUE \
           -DLLVM_ENABLE_LTO=${ENABLE_FLTO} \
           -DLLVM_MAIN_INCLUDE_DIR=/sources/llvm-project/llvm/include \
           -DLLVM_DIR=/sources/build-staging/llvm-project-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/llvm \
           -DLLVM_TABLEGEN=/sources/build-staging/llvm-project/bin/llvm-tblgen \
           -DSWIFT_ANDROID_NATIVE_SYSROOT=${PACKAGE_ROOT}/val-verde-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot \
           -DSWIFT_ANDROID_API_LEVEL=${HOST_OS_API_LEVEL} \
           -DSWIFT_ANDROID_DEPLOY_DEVICE_PATH=/data/local/tmp/swift-tests \
           -DSWIFT_ANDROID_NDK_GCC_VERSION=4.9 \
           -DSWIFT_ANDROID_NDK_PATH=${ANDROID_NDK_HOME} \
           -DSWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER=TRUE \
           -DSWIFT_BUILD_SOURCEKIT=TRUE \
           -DSWIFT_BUILD_SYNTAXPARSERLIB=TRUE \
           -DSWIFT_CMARK_LIBRARY_DIR=/sources/build-staging/swift-cmark-${HOST_OS}-${HOST_PROCESSOR} \
           -DSWIFT_PATH_TO_LIBDISPATCH_SOURCE=/sources/swift-corelibs-libdispatch \
           -DSWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=TRUE \
           -DSWIFT_HOST_VARIANT_ARCH=${HOST_PROCESSOR} \
           -DSWIFT_HOST_VARIANT_SDK=ANDROID \
           -DSWIFT_INCLUDE_DOCS=FALSE \
           -DSWIFT_INCLUDE_TESTS=FALSE \
           -DSWIFT_USE_LINKER=lld \
           -DSWIFT_PATH_TO_CMARK_SOURCE=/sources/swift-cmark \
           -DSWIFT_PATH_TO_CMARK_BUILD=/sources/build-staging/swift-cmark \
           -DSWIFT_NATIVE_CLANG_TOOLS_PATH=${PACKAGE_ROOT}/bin \
           -DSWIFT_NATIVE_LLVM_TOOLS_PATH=${PACKAGE_ROOT}/bin \
           -DSWIFT_NATIVE_SWIFT_TOOLS_PATH=${PACKAGE_ROOT}/bin \
           -DSWIFT_TOOLS_ENABLE_LTO=${ENABLE_FLTO} \
           -DUSE_POSIX_SEM=1 \
           -DUUID_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
           -DUUID_LIBRARY=${PACKAGE_PREFIX}/lib/libuuid.so \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android lldb build
FROM ANDROID_SWIFT_BUILDER AS ANDROID_LLDB_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-lldb \
    && export SOURCE_ROOT=/sources/llvm-project/lldb \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DBUILD_SHARED_LIBS=TRUE \
           -DClang_DIR=/sources/build-staging/llvm-project-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/clang \
           -DCMAKE_EXE_LINKER_FLAGS="-O2" \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCURSES_INCLUDE_DIRS=${PACKAGE_PREFIX}/include/ncurses \
           -DCURSES_LIBRARIES="${PACKAGE_PREFIX}/lib/libncurses.so;${PACKAGE_PREFIX}/lib/libtinfo.a" \
           -DLibEdit_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
           -DLibEdit_LIBRARIES=${PACKAGE_PREFIX}/lib/libedit.so \
           -DLIBLZMA_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
           -DLIBLZMA_LIBRARY=${PACKAGE_PREFIX}/lib/liblzma.so \
           -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
           -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
           -DLLDB_ENABLE_SWIFT_SUPPORT=TRUE \
           -DLLDB_INCLUDE_TESTS=FALSE \
           -DLLDB_PATH_TO_NATIVE_SWIFT_BUILD=/sources/build-staging/swift-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/swift \
           -DLLDB_TABLEGEN=/sources/build-staging/swift-lldb/bin/lldb-tblgen \
           -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
           -DLLVM_ENABLE_LIBCXX=TRUE \
           -DLLVM_ENABLE_LLD=TRUE \
           -DLLVM_ENABLE_LTO=${ENABLE_FLTO} \
           -DLLVM_LINK_LLVM_DYLIB=FALSE \
           -DLLVM_MAIN_INCLUDE_DIR=/sources/llvm-project/llvm/include \
           -DLLVM_DIR=/sources/build-staging/llvm-project-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/llvm \
           -DLLVM_TABLEGEN=/sources/build-staging/llvm-project/bin/llvm-tblgen \
           -DNATIVE_Clang_DIR=${PACKAGE_ROOT}/lib/cmake/clang \
           -DNATIVE_LLVM_DIR=${PACKAGE_ROOT}/lib/cmake/lib \
           -DPANEL_LIBRARIES=${PACKAGE_PREFIX}/lib/libpanel.so \
           -DSwift_DIR=/sources/build-staging/swift-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/swift \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# android libdispatch build
FROM ANDROID_LLDB_BUILDER AS ANDROID_LIBDISPATCH_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-corelibs-libdispatch \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DBUILD_TESTING=FALSE \
           -DCMAKE_BUILD_TYPE=MinSizeRel \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot -target ${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}" \
           -DENABLE_SWIFT=TRUE \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && mv install${PACKAGE_PREFIX}/lib/swift/linux \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS} \
    && mv install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${BUILD_PROCESSOR} \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${HOST_PROCESSOR} \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb

# remove host foundation and libdispatch to avoid module collisions
RUN apt remove -y ${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}-x86-64 \
                  ${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}-x86-64

# foundation build
FROM ANDROID_LIBDISPATCH_BUILDER AS ANDROID_FOUNDATION_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-corelibs-foundation \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCMAKE_Swift_COMPILER_TARGET=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
           -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot" \
           -DICU_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
           -DICU_LIBRARY=${PACKAGE_PREFIX}/lib/libicudataswift.so \
           -DICU_I18N_LIBRARY_RELEASE=${PACKAGE_PREFIX}/lib/libicui18nswift.so \
           -DICU_UC_LIBRARY_RELEASE=${PACKAGE_PREFIX}/lib/libicuucswift.so \
           -DCURL_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
           -DCURL_LIBRARY=${PACKAGE_PREFIX}/lib/libcurl.so \
           -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
           -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
           -Ddispatch_DIR=/sources/build-staging/swift-corelibs-libdispatch-${HOST_OS}-${HOST_PROCESSOR}/cmake/modules \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && mv install${PACKAGE_PREFIX}/lib/swift/linux \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS} \
    && mv install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${BUILD_PROCESSOR} \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${HOST_PROCESSOR} \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb

# xctest build
FROM ANDROID_FOUNDATION_BUILDER AS ANDROID_XCTEST_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-corelibs-xctest \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -Ddispatch_DIR=/sources/build-staging/swift-corelibs-libdispatch-${HOST_OS}-${HOST_PROCESSOR}/cmake/modules \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCMAKE_Swift_COMPILER_TARGET=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
           -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot" \
           -DFoundation_DIR=/sources/build-staging/swift-corelibs-foundation-${HOST_OS}-${HOST_PROCESSOR}/cmake/modules \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# reinstall host foundation and libdispatch
RUN dpkg -i /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${BUILD_OS}-${BUILD_PROCESSOR}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-foundation-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb \
            /sources/${PACKAGE_BASE_NAME}-swift-corelibs-libdispatch-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}.deb


# llbuild build
FROM ANDROID_XCTEST_BUILDER AS ANDROID_LLBUILD_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-llbuild \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd ${SOURCE_ROOT} \
    && git remote set-branches --add origin dutch-android-master \
    && git fetch origin dutch-android-master \
    && git checkout dutch-android-master \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCMAKE_Swift_COMPILER_TARGET=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
           -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot" \
           -DLLBUILD_SUPPORT_BINDINGS=Swift \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && rsync -aPx ${STAGE_ROOT}/lib/*.so* install${PACKAGE_PREFIX}/lib \
    && cd ${STAGE_ROOT}/install \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# swift-tools-support-core build
FROM ANDROID_LLBUILD_BUILDER AS ANDROID_SWIFT_TOOLS_SUPPORT_CORE_BUILDER

RUN export SOURCE_PACKAGE_NAME=swift-tools-support-core \
    && export SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME} \
    && export STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && cd ${SOURCE_ROOT} \
    && git remote set-branches --add origin dutch-android-master \
    && git fetch origin dutch-android-master \
    && git checkout dutch-android-master \
    && mkdir -p ${STAGE_ROOT} \
    && cd ${STAGE_ROOT} \
    && ${PACKAGE_BASE_NAME}-platform-sdk-cmake \
           -DCMAKE_C_FLAGS="-D__GLIBC_PREREQ\(a,b\)=1" \
           -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
           -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
           -DCMAKE_Swift_COMPILER_TARGET=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
           -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot" \
           ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && cd ${STAGE_ROOT} \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && mkdir -p install${PACKAGE_PREFIX} \
    && rsync -aPx lib install${PACKAGE_PREFIX} \
    && cd ${STAGE_ROOT}/install \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
