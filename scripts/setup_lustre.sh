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
log_analytics_name="$6"
log_analytics_workspace_id="$7"
log_analytics_key="$8"
oss_disk_setup="$9"

echo mds="$1"
echo n_oss="$2"
echo storage_account="$3" 
echo storage_sas="${4/sig=*/sig=REDACTED}"
echo storage_container="$5"
echo log_analytics_name="$6"
echo log_analytics_workspace_id="$7"
echo log_analytics_key="$8"
echo oss_disk_setup="$9"


# vars used in script
if [ -e /dev/nvme0n1 ]; then
	devices='/dev/nvme*n1'
	n_devices=$(echo $devices | wc -w)
	echo "Using $n_devices NVME devices"
elif [ -e /dev/sdc ]; then
	devices='/dev/sd[c-m]'
	n_devices=$(echo $devices | wc -w)
	echo "Using $n_devices NVME devices"
elif [ -e /dev/sdb ]; then
	devices='/dev/sdb'
	n_devices=1
	echo "Using ephemeral disk on /dev/sdb"
else
	echo "ERROR: cannot find devices for storage"
	exit 1
fi

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

if [[ "$n_devices" -gt "1" && ( "$oss_disk_setup" = "raid" || "$HOSTNAME" = "$mds" ) ]]; then
	device=/dev/md10
	echo "creating raid ($device) from $n_devices devices : $devices"
	$script_dir/create_raid0.sh $device $devices
	devices=$device
	n_devices=1
fi

echo "using $n_devices device(s) : $devices"

ost_index=1

if [ "$HOSTNAME" = "$mds" ]; then

	# SETUP MDS
	$script_dir/lfsmaster.sh $devices $n_oss

else

	echo "wait for the mds to start"
	modprobe lustre
	while ! lctl ping $mds@tcp; do
		sleep 2
	done


	idx=${HOSTNAME##${mds}-oss-}
	
	ost_index=$(( ( $idx * $n_devices ) + 1 ))

	echo "starting ost index=$ost_index"

	mds_ip=$(ping -c 1 $mds | head -1 | sed 's/^[^)]*(//g;s/).*$//g')

	$script_dir/lfsoss.sh $mds_ip "$devices" $ost_index

fi

if [ "${use_hsm,,}" = "true" ]; then

	if [ "$HOSTNAME" = "$mds" ]; then

		# IMPORT CONTAINER (so mount lustre on the mds to import)
		mkdir /lustre
		mount -t lustre ${mds}@tcp0:/LustreFS /lustre
		chmod 777 /lustre

		$script_dir/lfsimport.sh "$storage_account" "$storage_sas" "$storage_container" /lustre

	else

		$script_dir/lfshsm.sh "$mds" "$storage_account" "$storage_sas" "$storage_container"

	fi

fi

if [ "${use_log_analytics,,}" = "true" ]; then

	$script_dir/lfsloganalytics.sh $log_analytics_name $log_analytics_workspace_id "$log_analytics_key"

fi