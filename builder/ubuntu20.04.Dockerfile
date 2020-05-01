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
#Make below into a script (swift-compiler-apt-deps.sh)
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

RUN update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.lld" 20

COPY --from=BASE /sources /sources

#j11: number of logical cores + 1 (swift-compiler-build-script.sh)
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

RUN cd /sources/build/Ninja-Release/toolchain-linux-x86_64 \
   && mkdir -p local \
   && mv usr/* local \
   && mv local usr \
   && rm -rf usr/local/local \
   && cd usr/local/bin \
   && rm *test \
   && find . -type f -size +1M -print0 | xargs llvm-strip \
   #&& find . -type f -print0 | xargs -0 file | grep -vE "text|data|repl_swift" \
    #    | cut -d: -f1 | xargs llvm-strip \
   && cd ../lib \
   && find . -type f -size +1M -print0 | xargs llvm-strip
   #&& find . -type f -print0 | xargs -0 file | grep -vE "text|data" \
    #    | cut -d: -f1 | xargs llvm-strip

FROM ubuntu:20.04 AS PACKAGER

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
   && apt install -y alien

COPY --from=BUILDER /sources/build/Ninja-Release/toolchain-linux-x86_64/usr/local /usr/local

COPY ./swift-compiler-DEBIAN-control .

RUN tar -zvcf swift_build.tar.gz /usr/local \
    && alien swift_build.tar.gz 
RUN mkdir -p /tmp/swift-compiler-package \
    && dpkg-deb -R swift-build_1-2_all.deb /tmp/swift-compiler-package \
    && mv swift-compiler-DEBIAN-control /tmp/swift-compiler-package/DEBIAN/control \
    && dpkg -b /tmp/swift-compiler-package /swift-compiler.deb

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
    && apt install -y \
           libcurl4 \
           libedit2 \
           libpython2.7 \
           libxml2 \
           libz3-4

WORKDIR /artifacts

COPY --from=PACKAGER /swift-compiler.deb /

RUN mv ../swift-compiler.deb /artifacts

RUN dpkg -i swift-compiler.deb
CMD []

ENTRYPOINT ["tail", "-f", "/dev/null"]
#Use docker cp container_id:/artifacts/swift-compiler.deb /path/to/host/dir
