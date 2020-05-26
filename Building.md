### Pre-requisities

1. Docker for Linux (https://docs.docker.com/engine/install/ubuntu/)
1. Docker-compose for Linux (https://docs.docker.com/compose/install/)

### About

This document provides instructions to run the builders to generate swift-compiler debian packages for Ubuntu 20.04 and Android 10. Each of these folders contains Dockerfiles and corresponding build scripts


### How to build

1. Navigate to the directory that contains the `*.Dockerfile` and `docker-compose.yml`, and build the image based on the context and steps set in the `*.Dockerfile`.

1. Run `docker-compose build` to generate a build image based on the configs set in the `docker-compose.yml`. More context around the build such as name, tags, etc. can be added as needed the `build` setting in the compose file

1. Run `docker-compose up -d` to create a container based on the image created in the above step. This runs the container in a detached mode, and as specified in the compose file

1. To check the logs of the container, run `docker-compose logs -f builder`. To exec into a container, run `docker exec -it ubuntu-builder bash`. The string `ubuntu` can be replaced with `android` corresponding to the android container

1. If the intent is to run both build services, edit the `service` values in the `docker-compose.yml` files for uniqueness.

## Example instructions

1. To build and instantiate the ubuntu build:
`cd builders/ubuntu20.04 && docker-compose build && docker-compose up -d && docker exec -it ubuntu-builder bash`

1. Similarly for the android build:
`cd builders/android10 && docker-compose build && docker-compose up -d && docker exec -it android-builder bash`
