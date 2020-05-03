#!/bin/bash

apt update && apt upgrade -y && \
    apt install -y \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        expat \
        git \
        g++ \
        icu-devtools \
        libicu-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libncurses-dev \
        libpython2.7 \
        libpython2.7-dev \
        libssl-dev \
        libsqlite3-dev \
        libxml2-dev \
        lld \
        llvm \
        make \
        ninja-build \
        pkg-config \
        python \
        python3-distutils \
        python3-six \
        rsync \
        swig \
        ssh \
        uuid-dev && \
    apt autoremove && \
    apt clean

update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.lld" 20
