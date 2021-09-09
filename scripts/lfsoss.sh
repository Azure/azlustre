#!/bin/bash

# arg: $1 = lfsmaster
# arg: $2 = device (e.g. L=/dev/sdb Lv2=/dev/nvme0n1)
# arg: $3 = start index
master=$1
devices=$2
index=$3

ndevices=$(wc -w <<<$devices)

for device in $devices; do

    mkfs.lustre \
        --fsname=LustreFS \
        --backfstype=ldiskfs \
        --reformat \
        --ost \
        --mgsnode=$master \
        --index=$index \
        --mountfsoptions="errors=remount-ro" \
        $device

    mkdir /mnt/oss${index}
    echo "$device /mnt/oss${index} lustre noatime,nodiratime,nobarrier 0 2" >> /etc/fstab

    index=$(( $index + 1 ))

done

mount -a
