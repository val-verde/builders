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
ENV ENABLE_FLTO=OFF

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
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers \
     ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime \
     ${PACKAGE_BASE_NAME}-platform-sdk-curl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-expat-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c \
     ${PACKAGE_BASE_NAME}-platform-sdk-icu4c-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libedit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libffi-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libuuid-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-libxml2-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-llvm-project-bootstrap \
     ${PACKAGE_BASE_NAME}-platform-sdk-ncurses-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-openssl-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-python-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit \
     ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-sqlite-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-cmark-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-foundation \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-libdispatch \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-corelibs-xctest \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-doc-android \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-driver-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-format-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-llbuild \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-lldb \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-package-manager-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-syntax-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-swift-tools-support-core \
     ${PACKAGE_BASE_NAME}-platform-sdk-xz-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams \
     ${PACKAGE_BASE_NAME}-platform-sdk-yams-cross \
     ${PACKAGE_BASE_NAME}-platform-sdk-z3-cross \
     /sources/

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

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk

# android environment
ENV HOST_KERNEL=linux \
    HOST_OS=android \
    HOST_OS_API_LEVEL=29 \
    HOST_PROCESSOR=aarch64
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/sysroot/usr
ENV ENABLE_FLTO=
# android ndk headers build
FROM ANDROID_NDK_BUILDER AS ANDROID_NDK_HEADERS_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-headers

# android ndk runtime build
FROM ANDROID_NDK_HEADERS_BUILDER AS ANDROID_NDK_RUNTIME_BUILDER

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-android-ndk-runtime

# android icu build
FROM ANDROID_NDK_RUNTIME_BUILDER AS ANDROID_ICU_BUILDER

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
           -DSWIFT_PATH_TO_LIBDISPATCH_SOURCE=/sources/swift-corelibs-libdispatch \
           -DSWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=TRUE \
           -DSWIFT_HOST_VARIANT_ARCH=${HOST_PROCESSOR} \
           -DSWIFT_HOST_VARIANT_SDK=ANDROID \
           -DSWIFT_INCLUDE_DOCS=FALSE \
           -DSWIFT_INCLUDE_TESTS=FALSE \
           -DSWIFT_USE_LINKER=lld \
           -DSWIFT_PATH_TO_CMARK_SOURCE=/sources/swift-cmark \
           -DSWIFT_PATH_TO_CMARK_BUILD=/sources/build-staging/swift-cmark-${HOST_OS}-${HOST_PROCESSOR} \
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
           -DLLDB_PYTHON_DEFAULT_RELATIVE_PATH=lib/python2.7 \
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
           -DPYTHON_EXECUTABLE=/usr/bin/python2 \
           -DPYTHON_INCLUDE_DIRS=${PACKAGE_PREFIX}/include/python2.7 \
           -DPYTHON_LIBRARIES=${PACKAGE_PREFIX}/lib/libpython2.7.so \
           -DSwift_DIR=/sources/build-staging/swift-${HOST_OS}-${HOST_PROCESSOR}/lib/cmake/swift \
           -DSWIG_EXECUTABLE=/usr/bin/swig \
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
    && mv install${PACKAGE_PREFIX}/lib/swift/linux \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS} \
    && mv install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${BUILD_PROCESSOR} \
          install${PACKAGE_PREFIX}/lib/swift/${HOST_OS}/${HOST_PROCESSOR} \
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

RUN bash ${PACKAGE_BASE_NAME}-platform-sdk-pythonkit-android

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
