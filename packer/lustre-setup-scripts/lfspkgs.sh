#!/bin/bash

yum -y install lustre kmod-lustre-osd-ldiskfs lustre-osd-ldiskfs-mount lustre-resource-agents e2fsprogs lustre-tests || exit 1

sed -i 's/ResourceDisk\.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf

systemctl restart waagent

weak-modules --add-kernel --no-initramfs

if [ -f "/etc/systemd/system/temp-disk-swapfile.service" ]; then
    systemctl stop temp-disk-swapfile.service
    systemctl disable temp-disk-swapfile.service
fi

umount /mnt/resource

sed -i '/^ - disk_setup$/d;/^ - mounts$/d' /etc/cloud/cloud.cfg
sed -i '/azure_resource-part1/d' /etc/fstab
