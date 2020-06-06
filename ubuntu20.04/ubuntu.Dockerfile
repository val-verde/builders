FROM ubuntu:20.04 AS BASE

ENV DEBIAN_FRONTEND=noninteractive

ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT

WORKDIR /sources

ENV BOOTSTRAP_SCRIPT=bootstrap-${HOST_OS}-toolchain

COPY ${BOOTSTRAP_SCRIPT} .
RUN bash ${BOOTSTRAP_SCRIPT}

FROM BASE AS CMARK_BUILDER

ARG BUILD_KERNEL
ARG BUILD_OS
ARG BUILD_PROCESSOR
ARG DEB_PATH
ARG HOST_KERNEL
ARG HOST_OS
ARG HOST_PROCESSOR
ARG PACKAGE_BASE_NAME
ARG PACKAGE_ROOT

ENV BUILD_KERNEL=${BUILD_KERNEL}
ENV BUILD_OS=${BUILD_OS}
ENV BUILD_PROCESSOR=${BUILD_PROCESSOR}
ENV DEB_PATH=${DEB_PATH}
ENV HOST_KERNEL=${HOST_KERNEL}
ENV HOST_OS=${HOST_OS}
ENV HOST_PROCESSOR=${HOST_PROCESSOR}
ENV PACKAGE_BASE_NAME=${PACKAGE_BASE_NAME}
ENV PACKAGE_ROOT=${PACKAGE_ROOT}

ENV DEBIAN_FRONTEND=noninteractive
ENV BUILD_TRIPLE=${BUILD_PROCESSOR}-${BUILD_KERNEL}-${BUILD_OS}
ENV HOST_TRIPLE_SHORTENED=${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}
ENV HOST_TRIPLE=${HOST_TRIPLE_SHORTENED}
ENV PACKAGE_PREFIX=${PACKAGE_ROOT}

ENV SOURCE_PACKAGE_NAME=swift-cmark
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN git clone https://github.com/apple/${SOURCE_PACKAGE_NAME}.git  --single-branch --branch master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && cmake \
     -G Ninja \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
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

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && cmake \
     -G Ninja \
     -DBUILD_SHARED_LIBS=TRUE \
     -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
     -DCLANG_INCLUDE_DOCS=FALSE \
     -DCLANG_INCLUDE_TESTS=FALSE \
     -DCLANG_LINK_CLANG_DYLIB=FALSE \
     -DCLANG_TOOL_ARCMT_TEST_BUILD=FALSE \
     -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=FALSE \
     -DCLANG_TOOL_CLANG_REFACTOR_TEST_BUILD=FALSE \
     -DCLANG_TOOL_C_ARCMT_TEST_BUILD=FALSE \
     -DCLANG_TOOL_C_INDEX_TEST_BUILD=FALSE \
     -DCMAKE_AR=/usr/bin/llvm-ar \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_C_COMPILER=clang \
     -DCMAKE_C_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_CXX_COMPILER=clang++ \
     -DCMAKE_CXX_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_EXE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_LINKER=/usr/bin/ld.lld \
     -DCMAKE_MODULE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_NM=/usr/bin/llvm-nm \
     -DCMAKE_OBJCOPY=/usr/bin/llvm-objcopy \
     -DCMAKE_OBJDUMP=/usr/bin/llvm-objdump \
     -DCMAKE_RANLIB=/usr/bin/llvm-ranlib \
     -DCMAKE_READELF=/usr/bin/llvm-readelf \
     -DCMAKE_SHARED_LINKER_FLAGS="-s -O2" \
     -DCMAKE_STRIP=/usr/bin/llvm-strip \
     -DCOMPILER_RT_CAN_EXECUTE_TESTS=FALSE \
     -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
     -DHAVE_CXX_ATOMICS_WITH_LIB=TRUE \
     -DHAVE_CXX_ATOMICS64_WITH_LIB=TRUE \
     -DHAVE_GNU_POSIX_REGEX=TRUE \
     -DHAVE_INOTIFY=TRUE \
     -DHAVE_THREAD_SAFETY_ATTRIBUTES=TRUE \
     -DLIBOMPTARGET_DEP_LIBFFI_INCLUDE_DIR:PATH=/usr/include/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS} \
     -DLIBOMPTARGET_DEP_LIBELF_LIBRARIES:FILEPATH=/usr/lib/${HOST_PROCESSOR}-${HOST_KERNEL}-${HOST_OS}/libelf.so \
     -DLIBOMPTARGET_NVPTX_ALTERNATE_HOST_COMPILER=gcc-8 \
     -DLLD_INCLUDE_TESTS=FALSE \
     -DLLVM_BUILD_LLVM_DYLIB=FALSE \
     -DLLVM_BUILD_DOCS=FALSE \
     -DLLVM_BUILD_TESTS=FALSE \
     -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_PROCESSOR}-unknown-${HOST_KERNEL}-${HOST_OS} \
     -DLLVM_ENABLE_LIBCXX=TRUE \
     -DLLVM_ENABLE_LLD=TRUE \
     -DLLVM_ENABLE_LTO=Full \
     -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;libclc;libcxx;libcxxabi;lld;mlir;openmp;parallel-libs;polly;pstl" \
     -DLLVM_HOST_TRIPLE=${HOST_PROCESSOR}-unknown-${HOST_KERNEL}-${HOST_OS} \
     -DLLVM_INCLUDE_DOCS=FALSE \
     -DLLVM_INCLUDE_GO_TESTS=FALSE \
     -DLLVM_INCLUDE_TESTS=FALSE \
     -DLLVM_LINK_LLVM_DYLIB=FALSE \
     -DLLVM_POLLY_LINK_INTO_TOOLS=TRUE \
     -DLLVM_TARGETS_TO_BUILD=all \
     -DLLVM_TOOL_LLVM_C_TEST_BUILD=FALSE \
     ${SOURCE_ROOT}/llvm \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} MLIRCallOpInterfacesIncGen MLIRTypeInferOpInterfaceIncGen \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
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

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git  --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && touch /usr/local/bin/llvm-c-test \
    && touch /usr/local/bin/clang-import-test \
    && cmake  \
     -G Ninja \
     -DCMAKE_AR=/usr/bin/llvm-ar \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_C_COMPILER=/usr/local/bin/clang \
     -DCMAKE_C_FLAGS="-I/sources/build-staging/llvm-project/include" \
     -DCMAKE_C_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ \
     -DCMAKE_CXX_FLAGS="-I/sources/build-staging/llvm-project/include" \
     -DCMAKE_CXX_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_EXE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_LINKER=/usr/bin/ld.lld \
     -DCMAKE_MODULE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_NM=/usr/bin/llvm-nm \
     -DCMAKE_OBJCOPY=/usr/bin/llvm-objcopy \
     -DCMAKE_OBJDUMP=/usr/bin/llvm-objdump \
     -DCMAKE_RANLIB=/usr/bin/llvm-ranlib \
     -DCMAKE_READELF=/usr/bin/llvm-readelf \
     -DCMAKE_SHARED_LINKER_FLAGS="-s -O2" \
     -DClang_DIR=${PACKAGE_PREFIX}/lib/cmake/clang \
     -DLLVM_BUILD_LIBRARY_DIR=/sources/build-staging/llvm-project/lib \
     -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
     -DLLVM_ENABLE_LIBCXX=TRUE \
     -DLLVM_ENABLE_LTO=Full \
     -DLLVM_MAIN_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DLLVM_DIR=${PACKAGE_PREFIX}/lib/cmake/llvm \
     -DLLVM_TABLEGEN=${PACKAGE_ROOT}/bin/llvm-tblgen \
     -DSWIFT_BUILD_SOURCEKIT=FALSE \
     -DSWIFT_BUILD_SYNTAXPARSERLIB=FALSE \
     -DSWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=TRUE \
     -DSWIFT_INCLUDE_DOCS=FALSE \
     -DSWIFT_INCLUDE_TESTS=FALSE \
     -DSWIFT_USE_LINKER=lld \
     -DSWIFT_PATH_TO_CMARK_SOURCE=/sources/swift-cmark \
     -DSWIFT_PATH_TO_CMARK_BUILD=/sources/build-staging/swift-cmark \
     -DSWIFT_NATIVE_CLANG_TOOLS_PATH=${PACKAGE_ROOT}/bin \
     -DSWIFT_NATIVE_LLVM_TOOLS_PATH=${PACKAGE_ROOT}/bin \
     -DSWIFT_TOOLS_ENABLE_LTO=Full \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# lldb build
FROM SWIFT_BUILDER AS LLDB_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-lldb
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN mkdir -p ${STAGE_ROOT} \
             ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && cmake  \
     -G Ninja \
     -DCMAKE_AR=/usr/bin/llvm-ar \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_C_COMPILER=/usr/local/bin/clang \
     -DCMAKE_C_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ \
     -DCMAKE_CXX_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_EXE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_LINKER=/usr/bin/ld.lld \
     -DCMAKE_MODULE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_NM=/usr/bin/llvm-nm \
     -DCMAKE_OBJCOPY=/usr/bin/llvm-objcopy \
     -DCMAKE_OBJDUMP=/usr/bin/llvm-objdump \
     -DCMAKE_RANLIB=/usr/bin/llvm-ranlib \
     -DCMAKE_READELF=/usr/bin/llvm-readelf \
     -DCMAKE_SHARED_LINKER_FLAGS="-s -O2" \
     -DClang_DIR=${PACKAGE_PREFIX}/lib/cmake/clang \
     -DLLDB_ENABLE_SWIFT_SUPPORT=TRUE \
     -DLLDB_INCLUDE_TESTS=FALSE \
     -DLLVM_BUILD_MAIN_SRC_DIR=/sources/llvm-project/llvm \
     -DLLVM_ENABLE_LIBCXX=TRUE \
     -DLLVM_ENABLE_LTO=Full \
     -DLLVM_INCLUDE_TESTS=FALSE \
     -DLLVM_MAIN_INCLUDE_DIR=${PACKAGE_PREFIX}/include \
     -DLLVM_DIR=${PACKAGE_PREFIX}/lib/cmake/llvm \
     -DLLVM_TABLEGEN=${PACKAGE_ROOT}/bin/llvm-tblgen \
     -DLLDB_INCLUDE_TESTS=OFF \
     -DSwift_DIR=/sources/build-staging/swift/lib/cmake/swift \
     /sources/llvm-project/lldb \
     && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
     && ninja -j${NUM_PROCESSORS} \
     && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb \
    && dpkg -i ${DEB_PATH}/${PACKAGE_NAME}.deb

# libdispatch build
FROM LLDB_BUILDER AS DISPATCH_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-corelibs-libdispatch
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && cmake  \
     -G Ninja \
     -DBUILD_TESTING=FALSE \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_C_COMPILER=/usr/local/bin/clang \
     -DCMAKE_C_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ \
     -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
     -DCMAKE_CXX_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_EXE_LINKER_FLAGS="-s -O2" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
     -DCMAKE_SHARED_LINKER_FLAGS="-s -O2" \
     -DENABLE_SWIFT=TRUE \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb

# foundation build
FROM DISPATCH_BUILDER AS FOUNDATION_BUILDER

ENV SOURCE_PACKAGE_NAME=swift-corelibs-foundation
ENV SOURCE_ROOT=/sources/${SOURCE_PACKAGE_NAME}
ENV STAGE_ROOT=/sources/build-staging/${SOURCE_PACKAGE_NAME}

RUN git clone https://github.com/val-verde/${SOURCE_PACKAGE_NAME}.git --single-branch --branch dutch-master ${SOURCE_ROOT} \
    && mkdir -p ${STAGE_ROOT} \
                ${PACKAGE_ROOT}/${PACKAGE_BASE_NAME}-platform-sdk-${HOST_OS}-${HOST_PROCESSOR}

RUN cd ${STAGE_ROOT} \
    && cmake  \
     -G Ninja \
     -DCMAKE_BUILD_TYPE=MinSizeRel \
     -DCMAKE_C_COMPILER=/usr/local/bin/clang \
     -DCMAKE_C_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ \
     -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
     -DCMAKE_CXX_FLAGS_MINSIZEREL="-Oz" \
     -DCMAKE_INSTALL_PREFIX=${STAGE_ROOT}/install/${PACKAGE_PREFIX} \
     -DCMAKE_Swift_COMPILER=${PACKAGE_ROOT}/bin/swiftc \
     -DCMAKE_SHARED_LINKER_FLAGS="-s -O2" \
     -Ddispatch_DIR=/sources/build-staging/swift-corelibs-libdispatch/cmake/modules \
     ${SOURCE_ROOT} \
    && export NUM_PROCESSORS="$(($(getconf _NPROCESSORS_ONLN) + 1))" \
    && ninja -j${NUM_PROCESSORS} \
    && ninja -j${NUM_PROCESSORS} install

RUN cd ${STAGE_ROOT}/install \
    && export PACKAGE_NAME=${PACKAGE_BASE_NAME}-${SOURCE_PACKAGE_NAME}-${HOST_OS}-${HOST_PROCESSOR} \
    && tar cf ${PACKAGE_NAME}.tar usr/ \
    && alien ${PACKAGE_NAME}.tar \
    && mv *${SOURCE_PACKAGE_NAME}*.deb \
          ${DEB_PATH}/${PACKAGE_NAME}.deb

CMD []
ENTRYPOINT ["tail", "-f", "/dev/null"]
