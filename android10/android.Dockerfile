FROM ubuntu:20.04 AS BASE

ENV DEBIAN_FRONTEND=noninteractive

ARG ANDROID_NDK_PACKAGE_NAME
ARG ANDROID_NDK_URL
ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_OS_API_LEVEL
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT

ENV BOOTSTRAP_SCRIPT=bootstrap-${HOST_OS}-toolchain

WORKDIR /sources

RUN apt update \
    && apt install -y alien wget unzip

COPY ${BOOTSTRAP_SCRIPT} .

RUN chmod +x ${BOOTSTRAP_SCRIPT} \
    && ./${BOOTSTRAP_SCRIPT}

FROM ubuntu:20.04 AS ICU_BUILDER

ARG ANDROID_NDK_PACKAGE_NAME
ARG ANDROID_NDK_URL
ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_OS_API_LEVEL
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT

ENV ANDROID_NDK_PACKAGE_NAME=${ANDROID_NDK_PACKAGE_NAME}
ENV ANDROID_NDK_URL=${ANDROID_NDK_URL}
ENV BUILD_KERNEL=${BUILD_KERNEL}
ENV BUILD_OS=${BUILD_OS}
ENV BUILD_PROCESSOR=${BUILD_PROCESSOR}
ENV DEB_PATH=${DEB_PATH}
ENV HOST_KERNEL=${HOST_KERNEL}
ENV HOST_OS=${HOST_OS}
ENV HOST_OS_API_LEVEL=${HOST_OS_API_LEVEL}
ENV HOST_PROCESSOR=${HOST_PROCESSOR}
ENV PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME}
ENV PACKAGE_ROOT=${PACKAGE_ROOT}

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_NDK_HOME=${PACKAGE_ROOT}/${ANDROID_NDK_PACKAGE_NAME}
ENV BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}
ENV HOST_TRIPLE_SHORTENED=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}
ENV HOST_TRIPLE=${HOST_TRIPLE_SHORTENED}${HOST_OS_API_LEVEL}
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}
ENV PATH=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${BUILD_KERNEL}-${BUILD_PROCESSOR}/bin/:$PATH

WORKDIR /sources

COPY --from=BASE /sources/${ANDROID_NDK_PACKAGE_NAME}_1-2_all.deb /sources

RUN apt update \
    && apt install -y \
        alien \
        autoconf \
        automake \
        build-essential \
        gawk \
        m4 \
        make \
        ncurses-bin \
        wget \
    && dpkg -i ${ANDROID_NDK_PACKAGE_NAME}_1-2_all.deb

COPY wrap-configure .
RUN chmod +x wrap-configure 

ENV SOURCE_PACKAGE_NAME=icu
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT_PHASE_1=/sources/build-staging/${SOURCE_PACKAGE_NAME}-phase-1
ENV STAGE_ROOT_PHASE_2=/sources/build-staging/${SOURCE_PACKAGE_NAME}-phase-2
ENV UCONFIG_PATH=/sources/${SOURCE_PACKAGE_NAME}/source/common/unicode

COPY icu-uconfig-prepend.h .

RUN wget -c https://github.com/unicode-org/icu/releases/download/release-66-1/icu4c-66_1-src.tgz \
    && tar -zxf icu4c-66_1-src.tgz \
    && mkdir -p ${STAGE_ROOT_PHASE_1} \
                ${STAGE_ROOT_PHASE_2} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && echo "$(cat icu-uconfig-prepend.h) $(cat $UCONFIG_PATH/uconfig.h)" \
        > ${UCONFIG_PATH}/uconfig.h

#Phase 1 build
RUN cd ${STAGE_ROOT_PHASE_1} \
    && ${SOURCE_ROOT}/source/configure \
        --build=${BUILD_TRIPLE} \
        --disable-extras \
        --disable-samples \
        --disable-static \
        --disable-tests \
        --disable-tools \
        --enable-shared \
        --host=${BUILD_TRIPLE} \
        --prefix=${STAGE_ROOT_PHASE_1}/install/usr \
        --with-library-suffix=swift \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS}

#Phase 2 build
RUN cd ${STAGE_ROOT_PHASE_2} \
    && /sources/wrap-configure ${SOURCE_ROOT}/source/configure \
        --build=${BUILD_TRIPLE} \
        --disable-extras \
        --disable-samples \
        --disable-static \
        --disable-tests \
        --disable-tools \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT_PHASE_2}/install${PACKAGE_PREFIX} \
        --with-cross-build=${STAGE_ROOT_PHASE_1} \
        --with-library-suffix=swift \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT_PHASE_2}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# libxml2 build

FROM ICU_BUILDER AS XML_BUILDER 

ENV SOURCE_PACKAGE_NAME=libxml2
ENV SOURCE_PACKAGE_VERSION=2.9.10
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c http://xmlsoft.org/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
        --with-icu \
        --without-python \
        ICU_CFLAGS="-I${PACKAGE_PREFIX}/include" \
        ICU_LIBS="-L${PACKAGE_PREFIX}/lib" \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# libuuid build

FROM XML_BUILDER AS UUID_BUILDER 

ENV SOURCE_PACKAGE_NAME=libuuid
ENV SOURCE_PACKAGE_VERSION=1.0.3
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://sourceforge.net/projects/libuuid/files/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz/download \
    && mv download ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# sqlite3 build

FROM UUID_BUILDER AS SQLITE3_BUILDER

ENV SOURCE_PACKAGE_NAME=sqlite
ENV SOURCE_PACKAGE_VERSION=autoconf-3310100
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://sqlite.org/2020/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# openssl build

FROM SQLITE3_BUILDER AS OPENSSL_BUILDER

ENV SOURCE_PACKAGE_NAME=openssl
ENV SOURCE_PACKAGE_VERSION=1.1.1g
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://www.openssl.org/source/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && ${SOURCE_ROOT}/Configure \
        ${HOST_OS}-arm64 \
        -D__ANDROID_API__=${HOST_OS_API_LEVEL} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
        --openssldir=etc/ssl \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# curl build

FROM OPENSSL_BUILDER AS CURL_BUILDER

ENV SOURCE_PACKAGE_NAME=curl
ENV SOURCE_PACKAGE_VERSION=7.70.0
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://curl.haxx.se/download/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

ENV LIBS="-lcrypto -lssl -L${PACKAGE_PREFIX}/lib"
RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-doc \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
        --with-ssl=${PACKAGE_PREFIX} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb


# ncurses build

FROM CURL_BUILDER AS NCURSES_BUILDER 

ENV SOURCE_PACKAGE_NAME=ncurses
ENV SOURCE_PACKAGE_VERSION=6.2
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz \
    && rm -rf ${STAGE_ROOT}/* \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --enable-ext-colors \
        --enable-mixed-case \
        --enable-rpath \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${PACKAGE_PREFIX} \
        --with-curses-h \
        --with-cxx \
        --with-cxx-shared \
        --with-install-prefix=${STAGE_ROOT}/install \
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
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# libexpat build

FROM NCURSES_BUILDER AS EXPAT_BUILDER 

ENV SOURCE_PACKAGE_NAME=expat
ENV SOURCE_PACKAGE_VERSION=2.2.9
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://github.com/libexpat/libexpat/releases/download/R_2_2_9/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# cmark build

FROM EXPAT_BUILDER AS CMARK_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-cmark
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

COPY wrap-cmake .

RUN chmod +x wrap-cmake

RUN apt install -y cmake \
                    git \
                    ninja-build \
                    python \
    && rm -rf ${SOURCE_ROOT}/*

RUN git clone https://github.com/apple/${SOURCE_PACKAGE_NAME}.git  --single-branch --branch master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-cmake cmake \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb


# llvm build

FROM CMARK_BUILDER AS LLVM_BUILDER 

ENV SOURCE_PACKAGE_NAME=llvm-project
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

COPY wrap-cmake .

RUN chmod +x wrap-cmake

RUN apt install -y cmake \
                    git \
                    ninja-build \
                    python \
    && rm -rf ${SOURCE_ROOT}/*

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git --single-branch --branch dutch-android-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-cmake cmake \
     -DBUILD_SHARED_LIBS=ON \
     -DLLVM_ENABLE_LIBCXX=1 \
     -DLLVM_ENABLE_PROJECTS="clang;compiler-rt;lld;openmp;parallel-libs;polly;pstl;libclc" \
     -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}${HOST_OS_API_LEVEL} \
     -DLLVM_TARGETS_TO_BUILD=all \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
     -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
     ${SOURCE_ROOT}/llvm \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install


RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb


# swift build
FROM LLVM_BUILDER AS SWIFT_BUILDER

ENV SOURCE_PACKAGE_NAME=swift
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

COPY wrap-cmake .

RUN chmod +x wrap-cmake

COPY val-verde-swift-compiler.deb .

RUN apt install -y cmake \
                    git \
                    ninja-build \
                    pkg-config \
                    python3 \
                    libpython2.7 \
                    libz3-dev \
    && dpkg -i val-verde-swift-compiler.deb \
    && rm -rf ${SOURCE_ROOT}/*

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git  --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && touch /usr/local/bin/llvm-c-test \
    && touch /usr/local/bin/clang-import-test \
    && /sources/wrap-cmake cmake \
     -DCMAKE_C_FLAGS="-I/sources/build-staging/llvm-project/include -Wno-unused-command-line-argument -isystem ${ANDROID_NDK_HOME}/sources/android/support/include -isystem ${ANDROID_NDK_HOME}/sysroot/usr/include -isystem ${ANDROID_NDK_HOME}/sysroot/usr/include/aarch64-linux-android -L${ANDROID_NDK_HOME}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a" \
     -DCMAKE_CXX_FLAGS="-I/sources/build-staging/llvm-project/include -Wno-unused-command-line-argument -isystem ${ANDROID_NDK_HOME}/sources/cxx-stl/llvm-libc++/include -isystem ${ANDROID_NDK_HOME}/sources/cxx-stl/llvm-libc++abi/include -isystem ${ANDROID_NDK_HOME}/sources/android/support/include -isystem ${ANDROID_NDK_HOME}/sysroot/usr/include -isystem ${ANDROID_NDK_HOME}/sysroot/usr/include/aarch64-linux-android -L${ANDROID_NDK_HOME}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DClang_DIR=${PACKAGE_PREFIX}/lib/cmake/clang \
     -DLLVM_BUILD_LIBRARY_DIR=/sources/build-staging/llvm-project/lib \
     -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
     -DLLVM_ENABLE_LIBCXX=1 \
     -DLLVM_MAIN_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DLLVM_DIR=${PACKAGE_PREFIX}/lib/cmake/llvm \
     -DLLVM_TABLEGEN=${PACKAGE_ROOT}/bin/llvm-tblgen \
     -DICU_I18N_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
     -DICU_I18N_LIBRARIES=${PACKAGE_PREFIX}/lib/libicui18nswift.so \
     -DICU_UC_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
     -DICU_UC_LIBRARIES=${PACKAGE_PREFIX}/lib/libicuucswift.so \
     -DLibEdit_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
     -DLibEdit_LIBRARIES=${PACKAGE_PREFIX}/lib/libedit.so \
     -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
     -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
     -DSWIFT_ANDROID_NATIVE_SYSROOT=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot \
     -DSWIFT_ANDROID_API_LEVEL=${HOST_OS_API_LEVEL} \
     -DSWIFT_ANDROID_DEPLOY_DEVICE_PATH=/data/local/tmp/swift-tests \
     -DSWIFT_ANDROID_NDK_GCC_VERSION=4.9 \
     -DSWIFT_ANDROID_NDK_PATH=${ANDROID_NDK_HOME} \
     -DSWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER=1 \
     -DSWIFT_BUILD_SOURCEKIT=0\
     -DSWIFT_BUILD_SYNTAXPARSERLIB=0 \
     -DSWIFT_PATH_TO_CMARK_SOURCE=/sources/swift-cmark \
     -DSWIFT_PATH_TO_CMARK_BUILD=/sources/build-staging/swift-cmark \
     -DSWIFT_NATIVE_CLANG_TOOLS_PATH=${PACKAGE_ROOT}/bin \
     -DSWIFT_NATIVE_LLVM_TOOLS_PATH=${PACKAGE_ROOT}/bin \
     -DSWIFT_NATIVE_SWIFT_TOOLS_PATH=${PACKAGE_ROOT}/bin \
     -DUUID_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DUUID_LIBRARY=${PACKAGE_PREFIX}/lib/libuuid.so \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb


# libedit build

FROM SWIFT_BUILDER AS EDIT_BUILDER 

ENV SOURCE_PACKAGE_NAME=libedit
ENV SOURCE_PACKAGE_VERSION=20191231-3.1
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://www.thrysoee.dk/editline/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
         CFLAGS="-I/usr/local/val-verde-platform-sdk-android28-aarch64/include -I/usr/local/val-verde-platform-sdk-android28-aarch64/include/ncurses -D__STDC_ISO_10646__=201103L -DNBBY=CHAR_BIT" \
         CXXFLAGS="-I/usr/local/val-verde-platform-sdk-android28-aarch64/include -I/usr/local/val-verde-platform-sdk-android28-aarch64/include/ncurses -D__STDC_ISO_10646__=201103L -DNBBY=CHAR_BIT" \
         LDFLAGS="-L/usr/local/val-verde-platform-sdk-android28-aarch64/lib" \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# xz build
FROM EDIT_BUILDER AS XZ_BUILDER 

ENV SOURCE_PACKAGE_NAME=xz
ENV SOURCE_PACKAGE_VERSION=5.2.5
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN wget -c https://tukaani.org/${SOURCE_PACKAGE_NAME}/${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && tar -zxf ${SOURCE_PACKAGE_NAME}-${SOURCE_PACKAGE_VERSION}.tar.gz \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-configure ${SOURCE_ROOT}/configure \
        --build=${BUILD_TRIPLE} \
        --disable-static \
        --enable-shared \
        --host=${HOST_TRIPLE_SHORTENED} \
        --prefix=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
    && make -j${NUM_PROCESSORS} \
    && make -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# lldb build
FROM XZ_BUILDER AS LLDB_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-lldb
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

COPY wrap-cmake .

RUN chmod +x wrap-cmake

RUN apt install -y cmake \
                    git \
                    ninja-build \
                    pkg-config \
                    python3 \
                    libncurses-dev \
                    libpython2.7 \
                    libz3-dev \
                    swig \
    && rm -rf ${SOURCE_ROOT}/*

RUN cd /sources/llvm-project \
    && mkdir -p ${STAGE_ROOT} \
             ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && touch /usr/local/bin/llvm-c-test \
    && touch /usr/local/bin/clang-import-test \
    && /sources/wrap-cmake cmake \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DClang_DIR=${PACKAGE_PREFIX}/lib/cmake/clang \
     -DCURSES_INCLUDE_DIRS=${PACKAGE_PREFIX}/include/ncurses \
     -DCURSES_LIBRARIES="${PACKAGE_PREFIX}/lib/libncurses.so;${PACKAGE_PREFIX}/lib/libtinfo.so;-lz" \
     -DPANEL_LIBRARIES=${PACKAGE_PREFIX}/lib/libpanel.so \
     -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
     -DLLVM_ENABLE_LIBCXX=1 \
     -DLLVM_MAIN_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DLLVM_DIR=${PACKAGE_PREFIX}/lib/cmake/llvm \
     -DLLVM_TABLEGEN=${PACKAGE_ROOT}/bin/llvm-tblgen \
     -DLibEdit_INCLUDE_DIRS=${PACKAGE_PREFIX}/include \
     -DLibEdit_LIBRARIES=${PACKAGE_PREFIX}/lib/libedit.so \
     -DLIBLZMA_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DLIBLZMA_LIBRARY=${PACKAGE_PREFIX}/lib/liblzma.so \
     -DLIBXML2_INCLUDE_DIR=${PACKAGE_PREFIX}/include/libxml2 \
     -DLIBXML2_LIBRARY=${PACKAGE_PREFIX}/lib/libxml2.so \
     -DLLDB_INCLUDE_TESTS=OFF \
     -DLLDB_PATH_TO_NATIVE_SWIFT_BUILD=/sources/build-staging/swift/lib/cmake/swift \
     -DNATIVE_Clang_DIR=${PACKAGE_ROOT}/lib/cmake/clang \
     -DNATIVE_LLVM_DIR=${PACKAGE_ROOT}/lib/cmake/lib \
     -DSwift_DIR=/sources/build-staging/swift/lib/cmake/swift \
     /sources/llvm-project/lldb \
     && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
     && ninja -j${NUM_PROCESSORS} \
     && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# val-verdr-swift-compiler rebuild
# libedit after ncurses and before sqllite
# touch llvm ...lines to be deleted
# liblzma should be before curl
# line 63 add "/usr" to PACKAGE_PREFIX (must read ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}/usr)
# Need a package before libdispatch called bionic-crt (cp ${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/28/crt*.o ${PACKAGE_PREFIX})
# libdispatch build
FROM LLDB_BUILDER AS DISPATCH_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-corelibs-libdispatch
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

COPY wrap-cmake .

RUN chmod +x wrap-cmake

RUN apt install -y cmake \
                    git \
                    ninja-build \
                    python \
    && rm -rf ${SOURCE_ROOT}/*

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && /sources/wrap-cmake cmake \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
     -DCMAKE_Swift_FLAGS="-sdk ${PACKAGE_PREFIX} -target aarch64-unknown-linux-android28 -tools-directory ${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin -I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include -I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/aarch64-linux-android -L${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/28" \
     -DENABLE_SWIFT=ON \
     ${SOURCE_ROOT} \
     && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
     && ninja -j${NUM_PROCESSORS} \
     && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}${HOST_OS_API_LEVEL}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
