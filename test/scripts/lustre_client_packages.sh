#!/bin/bash

lustre_dir=latest-2.12-release

cat << EOF >/etc/yum.repos.d/LustrePack.repo
[lustreserver]
name=lustreserver
baseurl=https://downloads.whamcloud.com/public/lustre/${lustre_dir}/el7/patchless-ldiskfs-server/
enabled=1
gpgcheck=0

[e2fs]
name=e2fs
baseurl=https://downloads.whamcloud.com/public/e2fsprogs/latest/el7/
enabled=1
gpgcheck=0

[lustreclient]
name=lustreclient
baseurl=https://downloads.whamcloud.com/public/lustre/${lustre_dir}/el7/client/
enabled=1
gpgcheck=0
EOF

# install the right kernel devel if not installed
release_version=$(cat /etc/redhat-release | cut -d' ' -f4)
kernel_version=$(uname -r)

if ! rpm -q kernel-devel-${kernel_version}; then
    yum -y install http://olcentgbl.trafficmanager.net/centos/${release_version}/updates/x86_64/kernel-devel-${kernel_version}.rpm
fi

# install the client RPMs if not already installed
if ! rpm -q lustre-client lustre-client-dkms; then
    yum -y install lustre-client lustre-client-dkms || exit 1
fi
weak-modules --add-kernel $(uname -r)
