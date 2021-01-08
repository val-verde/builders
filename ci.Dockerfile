FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    VAL_VERDE_GH_TEAM=val-verde

RUN apt update \
    && apt install -y git jq ssh \
    && mkdir staging

WORKDIR /staging

COPY ./scripts/updateRepo .
COPY ./backends/bash/compiler-tools/share/val-verde-sources.json \
     /staging

#Execute script from within the container to see errord
RUN SOURCE_FILE=${VAL_VERDE_GH_TEAM}-sources.json \
    bash updateRepo

#Disable upon addition of travis.yml
ENTRYPOINT [ "tail", "-f", "/dev/null"]