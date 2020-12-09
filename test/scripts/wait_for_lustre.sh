#!/bin/bash

mds=$1

modprobe lustre
while ! lctl ping $mds@tcp; do
    sleep 2
done
