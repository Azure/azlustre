#!/bin/bash

# arg: $1 = lfsserver
# arg: $2 = storage account
# arg: $3 = storage key
# arg: $4 = storage container
master="$1"
storage_account="$2"
storage_sas="$3"
storage_container="$4"

mkdir -p /var/run/lhsmd
chmod 755 /var/run/lhsmd

mkdir -p /etc/lhsmd
chmod 755 /etc/lhsmd

cat <<EOF >/etc/lhsmd/agent
# Lustre NID and filesystem name for the front end filesystem, the agent will mount this
client_device="${master}@tcp:/LustreFS"

# Do you want to use S3 and POSIX, in this example we use POSIX
enabled_plugins=["lhsm-plugin-az"]

## Directory to look for the plugins
plugin_dir="/usr/libexec/lhsmd"

# TBD, I used 16
handler_count=16

# TBD
snapshots {
        enabled = false
}
EOF
chmod 600 /etc/lhsmd/agent

cat <<EOF >/etc/lhsmd/lhsm-plugin-az
num_threads=16
az_storage_account="$storage_account"
az_storage_sas="?$storage_sas"
az_kv_name=""
az_kv_secret_name=""
bandwidth=0
exportprefix=""
archive "archive1" {
    id=1
    num_threads=16
    root=""
    compression="off"
    container="$storage_container"
}
EOF
chmod 600 /etc/lhsmd/lhsm-plugin-az

cat <<EOF >/etc/systemd/system/lhsmd.service
[Unit]
Description=The lhsmd server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
PIDFile=/run/lhsmd.pid
ExecStartPre=/bin/mkdir -p /var/run/lhsmd
ExecStart=/sbin/lhsmd -config /etc/lhsmd/agent
Restart=always

[Install]
WantedBy=multi-user.target
EOF
chmod 600 /etc/systemd/system/lhsmd.service

systemctl daemon-reload
systemctl enable lhsmd
systemctl start lhsmd
