#!/usr/bin/env bash
##
## Container build for O-RAN E2 KPM Simulator for Traffic Steering xApp
##

# Exit script on first error
set -o errexit

# Use UBI-mini as base container image
container=$(buildah --name kpm_sim from registry.access.redhat.com/ubi8/ubi)

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

# Build kpm_sim for the actual e2 simulator program
# add json headers for c++ support 
buildah run $container mkdir /usr/local/include/nlohmann
buildah run $container git clone https://github.com/azadkuh/nlohmann_json_release.git
buildah run $container cp nlohmann_json_release/json.hpp /usr/local/include/nlohmann

# Build kpm_sim
buildah config --workingdir /oran/e2sim/e2sm_examples/kpm_e2sm/ $container
buildah run $container rm -fr .build
buildah run $container mkdir .build
buildah config --workingdir /oran/e2sim/e2sm_examples/kpm_e2sm/.build $container
buildah run $container cmake ..
buildah run $container make install

# Commit to local container storage
buildah commit $container kpmsim
