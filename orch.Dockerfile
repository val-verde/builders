FROM jpetazzo/dind AS BASE

WORKDIR /sources

COPY ubuntu20.04/ubuntu.Dockerfile .

COPY android10/android.Dockerfile .

RUN usermod -aG docker root \
    && service docker restart

RUN \
docker build \
    -f android.Dockerfile \
    -t ubuntu-builder \
    --build-arg BUILD_KERNEL=linux \
    --build-arg BUILD_OS=gnu \
    --build-arg BUILD_PROCESSOR=x86_64 \
    --build-arg DEB_PATH=/sources \
    --build-arg HOST_KERNEL=linux \
    --build-arg HOST_OS=gnu \
    --build-arg HOST_PROCESSOR=x86_64 \
    --build-arg PACKAGE_BASE_NAME=val-verde \
    --build-arg PACKAGE_ROOT=/usr/local .

RUN \
docker build \
    -f android.Dockerfile \
    -t android-builder \
    --build-arg ANDROID_NDK_PACKAGE_NAME=android-ndk-r21b \
    --build-arg ANDROID_NDK_URL=https://dl.google.com/android/repository \
    --build-arg BUILD_KERNEL=linux \
    --build-arg BUILD_OS=gnu \
    --build-arg BUILD_PROCESSOR=x86_64 \
    --build-arg DEB_PATH=/sources \
    --build-arg HOST_KERNEL=linux \
    --build-arg HOST_OS=android \
    --build-arg HOST_OS_API_LEVEL=28 \
    --build-arg HOST_PROCESSOR=aarch64 \
    --build-arg PACKAGE_BASE_NAME=val-verde \
    --build-arg PACKAGE_ROOT=/usr/local .

CMD []
ENTRYPOINT [ "tail", "-f", "/dev/null" ]
