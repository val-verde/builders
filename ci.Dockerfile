FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
    && apt install -y git ssh \
    && mkdir staging

WORKDIR /staging

COPY ./scripts/updateRepo .

#Execute script from within the container to see errord
#RUN bash updateRepo

#Disable upon addition of travis.yml
ENTRYPOINT [ "tail", "-f", "/dev/null"]