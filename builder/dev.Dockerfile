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

RUN git clone https://github.com/val-verde/swift.git && \
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

RUN update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.lld" 20

COPY --from=BASE /sources /sources

RUN python3 ./swift/utils/build-script \
    -j11 \
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

FROM ubuntu:20.04 AS PACKAGER

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
    && apt install -y \
           libedit-dev \
           libpython2.7 \
           libpython2.7-dev \
           libxml2-dev \
           libz3-4
# libxml2-dev, python2.7 and 2.7-dev are needed here to enable REPL/virtual env for swift

COPY --from=BUILDER /sources/build/Ninja-Release/toolchain-linux-x86_64/usr /usr/local

CMD []

ENTRYPOINT ["tail", "-f", "/dev/null"]

