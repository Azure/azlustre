#!/bin/bash

tier=$1
oss_user=$2
oss_hostfile=$3

if [ "$tier" = "eph" ]; then

    echo "running 'sudo ethtool -L eth1 tx 8 rx 8 && sudo ifconfig eth1 down && sudo ifconfig eth1 up' on nodes"

    pssh -t 0 -i -l $oss_user -h $oss_hostfile 'sudo ethtool -L eth1 tx 8 rx 8 && sudo ifconfig eth1 down && sudo ifconfig eth1 up'

fi