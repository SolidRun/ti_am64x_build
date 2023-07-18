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



# Build arguments, username and user id
ARG user
ARG userid

# If user passed no arguments, exit with an error
RUN if [ -z "$user" ]; then printf "\n\nuser argument not received\n\n"; exit -1; fi

RUN if [ -z "$userid" ]; then printf "\n\nuserid argument not received\n\n"; exit -1; fi


# Add user
RUN useradd -u $userid $user

# Run as user
USER $user
