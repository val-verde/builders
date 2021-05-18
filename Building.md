### Pre-requisities

1. Docker for Linux (https://docs.docker.com/engine/install/ubuntu/)
1. Docker-compose for Linux (https://docs.docker.com/compose/install/)

### About

This document provides instructions to run the builders to generate swift-compiler debian packages for Ubuntu 20.04 and Android 10. Each of these folders contains Dockerfiles and corresponding build scripts

### How to build

1. Run `docker-compose build` to generate build images based on the configs set in the `docker-compose.yml`. More context around the build such as name, tags, etc. can be added as needed the `build` setting in the compose file.

1. Run `docker-compose up -d` to create a container based on the image created in the above step. This runs the container in a detached mode, and as specified in the compose file. Similar options to specify a particular service to create containers as specified in the `docker-compose.yml` file.

1. To check the logs of the container, run `docker-compose logs -f <SERVICE_NAME>`. To exec into a container, run `docker exec -it <SERVICE_NAME> bash`.    

Note: Use `build-ubuntu-image` in the source root to generate using the dockerfile or make additional changes to the build config.

### Syncing repos (Testing)

1. Use `ci.Dockerfile` to run test-ci environments - currently work in progress and to be updated as part of travis ci integration.
