#!/usr/bin/env bash
##
## Container build for O-RAN E2 Simulator
##

# Exit script on first error
set -o errexit

# Use UBI as base container image
container=$(buildah --name e2sim from registry.access.redhat.com/ubi8/ubi)

buildah config --label maintainer="Federico 'tele' Rossi <ferossi@redhat.com>" $container

# Install packages to compile e2sim
buildah run $container dnf install -y --nobest --skip-broken --nogpgcheck --disableplugin=subscription-manager g++ gcc-c++ gcc rpm-build cmake make git lksctp-tools autoconf automake libtool \
	http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-devel-1.66.0-10.el8.x86_64.rpm \
	http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/lksctp-tools-devel-1.0.18-3.el8.x86_64.rpm \
	http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/bison-3.0.4-10.el8.x86_64.rpm \
	http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/flex-2.6.1-9.el8.x86_64.rpm \
	http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-1.66.0-10.el8.x86_64.rpm
	#http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-atomic-1.66.0-10.el8.x86_64.rpm \
	#http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-container-1.66.0-10.el8.x86_64.rpm \
	#http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-stacktrace-1.66.0-10.el8.i686.rpm

buildah run $container dnf clean all
buildah run $container rm -rf /var/cache/dnf

# Download e2sim dawn release
buildah run $container git clone -b dawn "https://gerrit.o-ran-sc.org/r/sim/e2-interface" /oran

# Compile e2sim
buildah config --workingdir /oran/e2sim $container
buildah run $container mkdir build
buildah config --workingdir /oran/e2sim/build $container
buildah run $container cmake ..
buildah run $container make package
buildah run $container cmake .. -DDEV_PKG=1
buildah run $container make package

# Install e2sim packages from the libraries
buildah run $container rpm -ivh e2sim-1.0.0-x86_64.rpm e2sim-devel-1.0.0-x86_64.rpm

# Build E2SIM sample app
buildah config --workingdir /oran/e2sim/previous $container
buildah config --env E2SIM_DIR=/oran/e2sim/previous $container
buildah run $container ./build_e2sim
buildah run $container cp build/ricsim /usr/bin/
buildah run $container cp build/e2sim /usr/bin/

# Commit to local container storage
buildah commit $container e2sim
