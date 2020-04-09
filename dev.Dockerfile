FROM ubuntu:18.04

# TODO: Retry building this image using ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN echo "deb mirror://mirrors.ubuntu.com/mirrors.txt bionic main restricted universe multiverse" > /etc/apt/sources.list \
    && echo "deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-security main restricted universe multiverse" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
    build-essential \
    ca-certificates \
    clang \
    pkg-config \
    git \
    make \
    ssh \
    python2.7 \
    python2.7-dev \
    python-pip \
    && apt-get autoremove \
    && apt-get clean

ADD https://cmake.org/files/v3.15/cmake-3.15.3-Linux-x86_64.sh /cmake-3.15.3-Linux-x86_64.sh
RUN mkdir /opt/cmake
RUN sh /cmake-3.15.3-Linux-x86_64.sh --prefix=/opt/cmake --skip-license
RUN ln -s /opt/cmake/bin/cmake /usr/bin/cmake
RUN cmake --version

RUN pip install six \
    && mkdir -p engine

WORKDIR /engine

RUN git clone https://github.com/apple/swift.git \
    && cd swift \
    && python ./utils/update-checkout --clone \
    && python ./utils/build-script

CMD []
#ENTRYPOINT ["/usr/bin/"]
ENTRYPOINT ["tail", "-f", "/dev/null"]