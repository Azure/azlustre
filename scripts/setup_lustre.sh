#!/bin/bash

exec > /var/log/setup_lustre.log                                                                      
exec 2>&1

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "script_dir = $script_dir"

mds="$1"
n_oss="$2"
storage_account="$3" 
storage_sas="$4"
storage_container="$5"
oss_disk_setup="$6"
deploy_policy_engine="$7"
mdt_storage_sku="$8"
ost_storage_sku="$9"


if [ "$HOSTNAME" = "$mds" ]; then
	storage_sku="$mdt_storage_sku"
else
	storage_sku="$ost_storage_sku"
fi

echo mds="$1"
echo n_oss="$2"
echo storage_account="$3" 
echo storage_sas="${4/sig=*/sig=REDACTED}"
echo storage_container="$5"
echo oss_disk_setup="$6"
echo deploy_policy_engine="$7"
echo mdt_storage_sku="$8"
echo ost_storage_sku="$9"
echo storage_sku="$storage_sku"


rbh="${mds}rbh"

lustre_version=2.12.5

if [ "$storage_account" = "" ]; then
	use_hsm=false
else
	use_hsm=true
fi

if [ "$log_analytics_name" = "" ]; then
	use_log_analytics=false
else
	use_log_analytics=true
fi

if [ "$HOSTNAME" = "$rbh" ]; then

	echo "wait for the mds to start"
	modprobe lustre
	while ! lctl ping $mds@tcp; do
		sleep 2
	done

else 

	# vars used in script
	if [ "$storage_sku" = "Ephemeral" ]; then
		if [ -e /dev/nvme0n1 ]; then
			devices='/dev/nvme*n1'
			n_devices=$(echo $devices | wc -w)
			echo "Using $n_devices NVME devices"
		elif [ -e /dev/disk/azure/resource ]; then
			devices='/dev/disk/azure/resource'
			n_devices=1
			echo "Using ephemeral disk on /dev/disk/azure/resource"
		else
			echo "ERROR: cannot find devices for storage"
			exit 1
		fi
	else
		if [ -d /dev/disk/azure/scsi1 ]; then
			devices='/dev/disk/azure/scsi1/*'
			n_devices=$(echo $devices | wc -w)

			echo "Using $n_devices managed disks"
		else
			echo "ERROR: cannot find devices for storage"
			exit 1
		fi
	fi

	if [[ "$n_devices" -gt "1" && ( "$oss_disk_setup" = "raid" || "$HOSTNAME" = "$mds" ) ]]; then
		device=/dev/md10
		echo "creating raid ($device) from $n_devices devices : $devices"
		$script_dir/create_raid0.sh $device $devices
		devices=$device
		n_devices=1
	fi

	echo "using $n_devices device(s) : $devices"


	if [ "$HOSTNAME" = "$mds" ]; then

		# SETUP MDS
		$script_dir/lfsmaster.sh $devices $n_oss

	else

		echo "wait for the mds to start"
		modprobe lustre
		while ! lctl ping $mds@tcp; do
			sleep 2
		done

		idx=0
		for c in $(echo ${HOSTNAME##$mds} | grep -o .); do
			echo $c		
			idx=$(($idx * 36))
			if [ -z "${c##[0-9]}" ]; then
				idx=$(($idx + $c))
			else
				idx=$(($(printf "$idx + 10 + %d - %d" "'${c^^}" "'A")))
			fi
		done
		
		ost_index=$(( ( $idx * $n_devices ) + 1 ))

		echo "starting ost index=$ost_index"

		mds_ip=$(ping -c 1 $mds | head -1 | sed 's/^[^)]*(//g;s/).*$//g')

		$script_dir/lfsoss.sh $mds_ip "$(echo $devices)" $ost_index

	fi

fi

if [ "${use_hsm,,}" = "true" ]; then

	if [ "$HOSTNAME" = "$mds" ]; then

		# deploy on the MDS if we aren't using a policy engine
		if [ "$deploy_policy_engine" = "True" ]; then

			# register cl1 - robinhood
			lctl --device LustreFS-MDT0000 changelog_register
			# register cl2 - lustremetasync
			lctl --device LustreFS-MDT0000 changelog_register

		else

			# IMPORT CONTAINER (so mount lustre on the mds to import)
			mkdir /lustre
			mount -t lustre ${mds}@tcp0:/LustreFS /lustre
			chmod 770 /lustre

			$script_dir/lfsimport.sh "$storage_account" "$storage_sas" "$storage_container" /lustre
		
		fi

	elif [ "$HOSTNAME" = "${rbh}" ]; then

		# IMPORT CONTAINER
		mkdir /lustre
		echo "${mds}@tcp0:/LustreFS /lustre lustre flock,defaults,_netdev 0 0" >> /etc/fstab
		while ! mount -a; do
			echo "Sleeping for 10s before retrying"
			sleep 10
		done
		chmod 770 /lustre
		
		$script_dir/lfsimport.sh "$storage_account" "$storage_sas" "$storage_container" /lustre
		
		$script_dir/lfsrbh.sh $mds "$storage_account" "$storage_sas" "$storage_container"

	else

		$script_dir/lfshsm.sh "$mds" "$storage_account" "$storage_sas" "$storage_container"

	fi

fi
