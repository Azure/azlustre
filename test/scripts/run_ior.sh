#!/bin/bash

hostfile=$1
nodes=$(wc -l <$hostfile)
ppn=$2
sz_in_gb=$3
cores=$(($nodes * $ppn))
oss_user=$4
oss_hostfile=$5
lustre_tier=$6
oss_disk_setup=$7
lustre_stripe=$8
ost_per_oss=$9

timestamp=$(date "+%Y%m%d-%H%M%S")

source /etc/profile.d/modules.sh
export MODULEPATH=/usr/share/Modules/modulefiles:/apps/modulefiles
module load gcc-9.2.0
module load mpi/impi_2018.4.274
module load ior

device_list=()
if [[ "$oss_disk_setup" = "raid" ]]; then
    device_list+=(md10)
elif [[ "$lustre_tier" = "eph" ]]; then
    for i in $(seq 0 $(( $ost_per_oss - 1 )) ); do
        device_list+=(nvme${i}n1)
    done
elif [[ "$lustre_tier" = "prem" || "$lustre_tier" = "std" ]]; then
    for i in $( seq 0 $(( $ost_per_oss - 1 )) ); do
        
        # get the letter for the device
        c_dec=$(printf "%d" "'c")
        dev_dec=$(( $c_dec + $i ))
        dev_hex=$(printf "%x" $dev_dec)
        dev_char=$(printf "\x$dev_hex")
        
        device_list+=(sd${dev_char})
    done
else
    echo "unrecognised lustre type ($lustre_tier)."
    exit 1
fi

devices=$(echo "${device_list[@]}" | tr ' ' ',')

echo "Monitoring devices: $devices"

pssh -t 0 -l $oss_user -h $oss_hostfile 'dstat -n -Neth0,eth1 -d -D'$devices' --output $(hostname)-'${timestamp}'.dstat' 2>&1 >/dev/null &

test_dir=/lustre/test-${timestamp}
lfs setstripe --stripe-count $lustre_stripe $test_dir
mpirun -np $cores -ppn $ppn -hostfile $hostfile ior -k -a POSIX -v -i 1 -B -m -d 1 -F -w -r -t 32M -b ${sz_in_gb}G -o $test_dir

lfs df -h
df -h /lustre

kill %1
for h in $(<${oss_hostfile}); do 
    scp ${oss_user}@${h}:'*'-${timestamp}.dstat .
done

results_dir=~/results-${lustre_tier}-${oss_disk_setup}-${lustre_stripe}-${timestamp}
mkdir $results_dir

for i in *-${timestamp}.dstat; do
    # remove the first value as it is often very high
    sed '1,5d' $i > ${results_dir}/${i%%-${timestamp}.dstat}.csv
done
