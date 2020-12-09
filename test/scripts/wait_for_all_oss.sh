#!/bin/bash

mount_point=$1
num_oss=$2
ost_per_oss=$3

# wait for all the OSS to be present first
while [ "$(lctl get_param osc.*.ost_conn_uuid | cut -d'=' -f2 | uniq | wc -l)" != "$num_oss" ]; do
    echo "    waiting for all $num_oss OSS"
    sleep 5
done

echo "all $num_ost OSS have started"

while [ "$(lctl get_param osc.*.ost_conn_uuid | cut -d'=' -f2 | uniq -c | sed 's/^ *//g' | cut -f1 -d' ' | uniq -c | sed 's/^ *//g')" != "$num_oss $ost_per_oss" ]; do
    echo "   waiting for all $ost_per_oss OSTs on each OSS"
    sleep 5
done
