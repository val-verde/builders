#!/bin/bash
set -e

tar -zvcf swift_build.tar.gz /usr/local \
    && alien swift_build.tar.gz 

mkdir -p /tmp/swift-compiler-package \
    && dpkg-deb -R swift-build_1-2_all.deb /tmp/swift-compiler-package \
    && mv swift-compiler-DEBIAN-control /tmp/swift-compiler-package/DEBIAN/control \
    && dpkg -b /tmp/swift-compiler-package /val-verde-swift-compiler.deb
