ARG BASE_IMG

FROM ${BASE_IMG} as dev-stage

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates curl gdb git \
    inetutils-traceroute iproute2 ipsec-tools iputils-ping \
    libapr1 libmbedcrypto1 libmbedtls10 libmbedx509-0 libtool \
    make mc nano netcat python software-properties-common sudo supervisor \
    telnet unzip wget \
 && rm -rf /var/lib/apt/lists/*

#RUN echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic multiverse universe main restricted" >> /etc/apt/sources.list
#RUN echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic-updates multiverse restricted universe main" >> /etc/apt/sources.list
#RUN echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic-backports main multiverse restricted universe" >> /etc/apt/sources.list
#RUN cat /etc/apt/sources.list



COPY Makefile Makefile
RUN mkdir -p build-data/platforms
COPY build-data/platforms/aarch64-generic.mk build-data/platforms/aarch64-generic.mk

RUN UNATTENDED=y make --trace PLATFORM=aarch64-generic install-dep

WORKDIR /


