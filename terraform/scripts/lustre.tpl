#!/bin/bash

# Reworked scripts to set up MDS+MGS on one machine + multiple OSS nodes
# Sources can be found at:
# - https://github.com/Azure/azure-quickstart-templates/blob/master/intel-lustre-client-server/scripts/lustre.sh (MIT)
# - https://github.com/Azure/azurehpc/blob/master/scripts/lfsrepo.sh (MIT)
# - https://github.com/Azure/azurehpc/blob/master/scripts/lfspkgs.sh (MIT)
#
# Changes:
# * Updated for CentOS 7.9
# * Modified to work with cloud-init
# * TPL'd for Terraform templatefile functionality

log()
{
	echo "$1"
	logger "$1"
}

fatal() {
    msg=$${1:-"Unknown Error"}
    log "FATAL ERROR: $msg"
    exit 1
}

# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( attempt_num == max_attempts ))
        then
            log "Command $cmd attempt $attempt_num failed and there are no more attempts left!"
			return 1
        else
            log "Command $cmd attempt $attempt_num failed. Trying again in 5 + $attempt_num seconds..."
            sleep $(( 5 * attempt_num++ ))
        fi
    done
}

add_to_fstab() {
	device="$${1}"
	mount_point="$${2}"
	if grep -q "$device" /etc/fstab
	then
		log "Not adding $device to /etc/fstab (it's  already there)"
	else
		line="$device $mount_point lustre defaults,_netdev 0 0"
		log "$${line}"
		echo -e "$${line}" >> /etc/fstab
	fi
}

# Parameters to be set through TF
node_type=${type}
node_index=$((${index}))
node_type_disk_count=${diskcount}
mgs_ip=${mgs_ip}
file_system_name=${fs_name}

log "node_type=$node_type node_type_disk_count=$node_type_disk_count node_index=$node_index mgs_ip=$mgs_ip file_system_name=$file_system_name"

create_mgs_mdt() {
	log "Creating MGS and MDT node (Headnode) on /dev/sdc"
	
	# TODO Make this dynamic?
	device="/dev/sdc"	

	# Make MGS filesystem which is always on /dev/sdc of the MGS node
	mkfs.lustre --fsname=$file_system_name --mgs --mdt --mountfsoptions="user_xattr,errors=remount-ro" --backfstype=ldiskfs --reformat $device --index 0 || exit 1

	uuid=$(blkid -o value -s UUID /dev/sdc)
	log "Node UUID=$uuid"
	label=$(blkid -c/dev/null -o value -s LABEL /dev/sdc)	
	log "Node label=$label"

	mount_point="/mnt/mgsmds"

	mkdir -p $mount_point

	# Add to /etc/fstab so that mount persists across reboots
	add_to_fstab "UUID=$uuid" $mount_point
	retry 5 mount -a

	log "Mounted $device as $mount_point"

	# # set up hsm
    # lctl set_param -P mdt.*-MDT0000.hsm_control=enabled
    # lctl set_param -P mdt.*-MDT0000.hsm.default_archive_id=1
    # lctl set_param mdt.*-MDT0000.hsm.max_requests=128

    # # allow any user and group ids to write
    # lctl set_param mdt.*-MDT0000.identity_upcall=NONE
}

create_oss() {
	log "Creating OSS node (Datanode)"

	devices_list=($(ls -1 /dev/sd* | egrep -v "/dev/sda|/dev/sdb" | egrep -v "[0-9]$"))
	
	((index=$node_index*$node_type_disk_count))

	log "DEVICES=$${devices_list}"

	for device in "$${devices_list[@]}";
	do
		log "Setting up $device on $index"
		mkfs.lustre \
			--fsname=$file_system_name \
			--backfstype=ldiskfs \
			--reformat \
			--ost \
			--mgsnode=$mgs_ip \
			--index=$index \
			--mountfsoptions="errors=remount-ro" \
			$device

		uuid=$(blkid -o value -s UUID $device)
		log "Node UUID=$uuid"
		label=$(blkid -c/dev/null -o value -s LABEL $device)	
		log "Node label=$label"

		mount_point="/mnt/oss/$label"
		mkdir -p $mount_point

		# Add to /etc/fstab so that mount persists across reboots	
		add_to_fstab "UUID=$uuid" $mount_point			

		log "Mounted $device as $mount_point"
		((index=index+1))
	done
	retry 5 mount -a
}

install_lustre() {
	## Add repositories for Lustre

	lustre_version=${lustre_version}

	if [ "$lustre_version" = "2.10" -o "$lustre_version" = "2.12" ]; then
		lustre_dir=latest-$${lustre_version}-release
	else
		lustre_dir="lustre-$lustre_version"
	fi

	cat << EOF >/etc/yum.repos.d/LustrePack.repo
[lustreserver]
name=lustreserver
baseurl=https://downloads.whamcloud.com/public/lustre/$${lustre_dir}/el7/patchless-ldiskfs-server/
enabled=1
gpgcheck=0
[e2fs]
name=e2fs
baseurl=https://downloads.whamcloud.com/public/e2fsprogs/latest/el7/
enabled=1
gpgcheck=0
[lustreclient]
name=lustreclient
baseurl=https://downloads.whamcloud.com/public/lustre/$${lustre_dir}/el7/client/
enabled=1
gpgcheck=0
EOF

	## Install Lustre packages

	yum -y install lustre kmod-lustre-osd-ldiskfs lustre-osd-ldiskfs-mount lustre-resource-agents e2fsprogs lustre-tests || exit 1

	sed -i 's/ResourceDisk\.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
	systemctl restart waagent

	log "Running weak-modules, this takes a bit ..."
	weak-modules --add-kernel --no-initramfs

	if [ -f "/etc/systemd/system/temp-disk-swapfile.service" ]; then
		systemctl stop temp-disk-swapfile.service
	fi

	umount /mnt/resource
}

## Bootstrap nodes

install_lustre

if [ "$node_type" == "HEAD" ]; then
	create_mgs_mdt
fi

if [ "$node_type" == "OSS" ]; then
	sleep 3m
	create_oss
fi
