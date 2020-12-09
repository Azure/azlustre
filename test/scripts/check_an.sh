#!/bin/bash

user=$1
hostlist=$2

pssh -l $user -i -h $hostlist '/usr/sbin/lspci | grep Mellanox'
