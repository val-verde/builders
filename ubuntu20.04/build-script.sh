#!/bin/bash

declare -i procNum="$(($(getconf _NPROCESSORS_ONLN) + 1))"

python3 ./swift/utils/build-script \
    -j$procNum \
    -l \
    -A \
    -R \
    --build-swift-static-sdk-overlay=true \
    --build-swift-static-stdlib=true \
    --use-gold-linker=false \
    --libdispatch \
    --foundation \
    --libicu \
    --llbuild \
    --lldb \
    --llvm-install-components="all" \
    --pythonkit \
    --sourcekit-lsp \
    --swiftpm \
    --swiftsyntax \
    --xctest \
    --install-llbuild \
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

cd /sources/build/Ninja-Release/swift-linux-x86_64 \ 
    && mkdir -p local \
    && mv usr/* local \
    && mv local usr \
    && rm -rf usr/local/local \
    && cd usr/local/bin \
    && find . -type f -print0 | xargs -0 file | grep -vE "text|data|repl_swift" \
        | cut -d: -f1 | xargs llvm-strip \
    && cd ../lib \
    && find . -type f -name "*.so" -o -name "*.a" -print0 | xargs llvm-strip
