FROM debian:bullseye

# enable backports
RUN printf "deb http://deb.debian.org/debian bullseye-backports main\n" >> /etc/apt/sources.list

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
		bc bison build-essential ca-certificates cmake cpio crossbuild-essential-arm64 crossbuild-essential-armhf debootstrap device-tree-compiler e2tools fakeroot fdisk flex git kmod libncurses-dev libssl-dev make mtools parted python3-cryptography python3-dev python3-jsonschema python3-pycryptodome python3-pyelftools python3-setuptools python3-yaml rsync sudo swig u-boot-tools unzip wget xz-utils; \
	apt-get --no-install-recommends -t bullseye-backports -y install qemu-system-arm; \
	:

# build environment
WORKDIR /ti_build
COPY shflags /
COPY entry.sh /
ENTRYPOINT ["/bin/sh", "/entry.sh"]
