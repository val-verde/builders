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

RUN git clone https://github.com/val-verde/swift.git \
    && python3 ./swift/utils/update-checkout --clone \
    && find . -type d -mindepth 1 -name ".*" | xargs rm -rf

FROM BASE AS BUILDER

ENV DEBIAN_FRONTEND=noninteractive

ADD ./apt-deps.sh .

RUN chmod +x apt-deps.sh && ./apt-deps.sh

COPY --from=BASE /sources /sources

ADD ./build-script.sh .

RUN chmod +x build-script.sh && ./build-script.sh

FROM ubuntu:20.04 AS PACKAGER

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
   && apt install -y alien

COPY --from=BUILDER /sources/build/Ninja-Release/toolchain-linux-x86_64/usr/local /usr/local

ADD ./swift-compiler-DEBIAN-control .

ADD ./package.sh .

RUN chmod +x package.sh && ./package.sh

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

COPY --from=PACKAGER /val-verde-swift-compiler.deb /

RUN mv ../val-verde-swift-compiler.deb /artifacts

RUN dpkg -i val-verde-swift-compiler.deb
CMD []

ENTRYPOINT ["tail", "-f", "/dev/null"]
#Use docker cp container_id:/artifacts/val-verde-swift-compiler.deb /path/to/host/dir
