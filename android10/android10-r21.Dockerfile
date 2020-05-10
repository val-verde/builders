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

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]