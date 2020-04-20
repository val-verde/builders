FROM ubuntu:20.04 AS BASE

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y \
        git \
        python3 \
        ssh

RUN if [ -d sources ]; then rm -rf sources; fi && \
    mkdir -p sources

WORKDIR /sources

RUN git clone https://github.com/apple/swift.git && \
    python3 ./swift/utils/update-checkout --clone

FROM BASE AS BUILDER

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        expat \
        git \
        g++ \
        libicu-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libncurses-dev \
        libpython2-dev \
        libssl-dev \
        libsqlite3-dev \
        libxml2-dev \
        lld \
        make \
        ninja-build \
        pkg-config \
        python \
        python3-distutils \
        python3-six \
        rsync \
        ssh \
        uuid-dev && \
    apt autoremove && \
    apt clean

RUN update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.lld" 20

COPY --from=BASE /sources /sources

RUN python3 ./swift/utils/build-script \
    -l \
    -A \
    -R \
    --build-swift-static-sdk-overlay=true \
    --build-swift-static-stdlib=true \
    --libdispatch \
    --foundation \
    --libicu \
    --libcxx \
    --llbuild \
    --lldb \
    --llvm-install-components="all" \
    --pythonkit \
    --sourcekit-lsp \
    --swiftpm \
    --swiftsyntax \
    --xctest \
    --install-llbuild \
    --install-libcxx \
    --install-lldb \
    --install-libdispatch \
    --install-foundation \
    --install-libicu \
    --install-pythonkit \
    --install-sourcekit-lsp \
    --install-static-libdispatch \
    --install-static-foundation \
    --install-swift \
    --install-swiftpm \
    --install-swiftsyntax \
    --install-xctest


CMD []

ENTRYPOINT ["tail", "-f", "/dev/null"]