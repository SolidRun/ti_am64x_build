FROM ubuntu:20.04

# retry at least 3 times to succeed on sketchy connections
RUN printf 'Acquire::http { Proxy "%s"; };\n' $APTPROXY | tee -a /etc/apt/apt.conf.d/proxy

# apt proxy (optional)
ARG APTPROXY=
RUN printf 'Acquire::Retries 3;\n' | tee -a /etc/apt/apt.conf.d/retry || true

# prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# install updates
RUN set -e; \
	apt-get update; \
	apt-get upgrade -y; \
	:

# Install packages
RUN set -e; \
	apt-get update; \
	apt-get --no-install-recommends -y install \
		bc bison build-essential ca-certificates cpio crossbuild-essential-arm64 crossbuild-essential-armhf debootstrap device-tree-compiler e2tools fakeroot fdisk flex git kmod libncurses-dev libssl-dev make mtools parted python2-dev python3-dev python3-pyelftools qemu-system-arm rsync sudo swig u-boot-tools unzip wget xz-utils; \
	:

# Install python modules
RUN set -e; \
	apt-get update; \
	apt-get --no-install-recommends -y install python3-pip; \
	pip3 install pycryptodome; \
	:

# Set workdir
WORKDIR /ti_build



# podman uses namespaces to create fake root user,
# mapping the actual podman process owner to uid 0 inside container
USER root
