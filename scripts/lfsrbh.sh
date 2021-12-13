#!/bin/bash

mds="$1"
storage_account="$2"
storage_sas="$3"
storage_container="$4"

lfs_mount=/lustre

# install deps
yum install -y mariadb-server mariadb-devel jemalloc expect

# install rbh packages
yum install -y \
    https://azurehpc.azureedge.net/rpms/robinhood-adm-3.1.6-1.x86_64.rpm \
    https://azurehpc.azureedge.net/rpms/robinhood-tools-3.1.6-1.lustre2.12.el7.x86_64.rpm \
    https://azurehpc.azureedge.net/rpms/robinhood-lustre-3.1.6-1.lustre2.12.el7.x86_64.rpm


# enable and start DB
systemctl enable mariadb
systemctl start mariadb

# create DB password
rbhpass=$(openssl rand -base64 12)
rbh-config create_db lustre "%" "$rbhpass" || exit 1
echo "$rbhpass" > /etc/robinhood.d/.dbpassword
chmod 600 /etc/robinhood.d/.dbpassword

rbh_config_file=/etc/robinhood.d/lustre.conf
cat <<EOF >$rbh_config_file
# -*- mode: c; c-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim:expandtab:shiftwidth=4:tabstop=4:

General
{
    fs_path = "/lustre";
    fs_type = lustre;
    stay_in_fs = yes;
    check_mounted = yes;
    last_access_only_atime = no;
    uid_gid_as_numbers = no;
}

# logs configuration
Log
{
    # log levels: CRIT, MAJOR, EVENT, VERB, DEBUG, FULL
    debug_level = EVENT;

    # Log file
    log_file = "/var/log/robinhood.log";

    # File for reporting purge events
    report_file = "/var/log/robinhood_actions.log";
    alert_file = "/var/log/robinhood_alerts.log";
    changelogs_file = "/var/log/robinhood_cl.log";

    stats_interval = 5min;

    batch_alert_max = 5000;
    alert_show_attrs = yes;
    log_procname = yes;
    log_hostname = yes;
}

# updt params configuration
db_update_params
{
    # possible policies for refreshing metadata and path in database:
    #   never: get the information once, then never refresh it
    #   always: always update entry info when processing it
    #   on_event: only update on related event
    #   periodic(interval): only update periodically
    #   on_event_periodic(min_interval,max_interval)= on_event + periodic

    # Updating of file metadata
    md_update = always ;
    # Updating file path in database
    path_update = on_event_periodic(0,1h) ;
    # File classes matching
    fileclass_update = always ;
}

# list manager configuration
ListManager
{
    # Method for committing information to database.
    # Possible values are:
    # - "autocommit": weak transactions (more efficient, but database inconsistencies may occur)
    # - "transaction": manage operations in transactions (best consistency, lower performance)
    # - "periodic(<nb_transaction>)": periodically commit (every <n> transactions).
    commit_behavior = transaction ;

    # Minimum time (in seconds) to wait before trying to reestablish a lost connection.
    # Then this time is multiplied by 2 until reaching connect_retry_interval_max
    connect_retry_interval_min = 1 ;
    connect_retry_interval_max = 30 ;
    # disable the following options if you are not interested in
    # user or group stats (to speed up scan)
    accounting  = enabled ;

    MySQL
    {
        server = "localhost" ;
        db     = "lustre" ;
        user   = "robinhood" ;
        password_file = "/etc/robinhood.d/.dbpassword" ;
        # port   = 3306 ;
        # socket = "/tmp/mysql.sock" ;
        engine = InnoDB ;
    }
}

# entry processor configuration
EntryProcessor
{
    # nbr of worker threads for processing pipeline tasks
    nb_threads = 16 ;

    # Max number of operations in the Entry Processor pipeline.
    # If the number of pending operations exceeds this limit, 
    # info collectors are suspended until this count decreases
    max_pending_operations = 100 ;

    # max batched DB operations (1=no batching)
    max_batch_size = 100;

    # Optionnaly specify a maximum thread count for each stage of the pipeline:
    # <stagename>_threads_max = <n> (0: use default)
    # STAGE_GET_FID_threads_max = 4 ;
    # STAGE_GET_INFO_DB_threads_max     = 4 ;
    # STAGE_GET_INFO_FS_threads_max     = 4 ;
    # STAGE_PRE_APPLY_threads_max       = 4 ;
    # Disable batching (max_batch_size=1) or accounting (accounting=no)
    # to allow parallelizing the following step:
    # STAGE_DB_APPLY_threads_max        = 4 ;

    # if set to 'no', classes will only be matched
    # at policy application time (not during a scan or reading changelog)
    match_classes = yes;

    # Faking mtime to an old time causes the file to be migrated
    # with top priority. Enabling this parameter detect this behavior
    # and doesn't allow  mtime < creation_time
    detect_fake_mtime = no;
}

# FS scan configuration
FS_Scan
{
    # simple scan interval (fixed)
    scan_interval      =   2d ;

    # min/max for adaptive scan interval:
    # the more the filesystem is full, the more frequently it is scanned.
    #min_scan_interval      =   24h ;
    #max_scan_interval      =    7d ;

    # number of threads used for scanning the filesystem
    nb_threads_scan        =     2 ;

    # when a scan fails, this is the delay before retrying
    scan_retry_delay       =    1h ;

    # timeout for operations on the filesystem
    scan_op_timeout        =    1h ;
    # exit if operation timeout is reached?
    exit_on_timeout        =    yes ;
    # external command called on scan termination
    # special arguments can be specified: {cfg} = config file path,
    # {fspath} = path to managed filesystem
    #completion_command     =    "/path/to/my/script.sh -f {cfg} -p {fspath}" ;

    # Internal scheduler granularity (for testing and of scan, hangs, ...)
    spooler_check_interval =  1min ;

    # Memory preallocation parameters
    nb_prealloc_tasks      =   256 ;

    Ignore
    {
        # ignore ".snapshot" and ".snapdir" directories (don't scan them)
        type == directory
        and
        ( name == ".snapdir" or name == ".snapshot" )
    }
}

# changelog reader configuration
# Parameters for processing MDT changelogs :
ChangeLog
{
    # 1 MDT block for each MDT :
    MDT
    {
        # name of the first MDT
        mdt_name  = "MDT0000" ;

        # id of the persistent changelog reader
        # as returned by "lctl changelog_register" command
        reader_id = "cl1" ;
    }

    # clear changelog every 1024 records:
    batch_ack_count = 1024 ;

    force_polling    = yes ;
    polling_interval = 1s ;
    # changelog batching parameters
    queue_max_size   = 1000 ;
    queue_max_age    = 5s ;
    queue_check_interval = 1s ;
    # delays to update last committed record in the DB
    commit_update_max_delay = 5s ;
    commit_update_max_delta = 10k ;

    # uncomment to dump all changelog records to the file
}

# policies configuration
# Load policy definitions for Lustre/HSM
%include "includes/lhsm.inc"

#### Fileclasses definitions ####

FileClass small_files {
    definition { type == file and size > 0 and size <= 16MB }
    # report = yes (default)
}
FileClass std_files {
    definition { type == file and size > 16MB and size <= 1GB }
}
FileClass big_files {
    definition { type == file and size > 1GB }
}

lhsm_config {
    # used for 'undelete': command to change the fid of an entry in archive
    rebind_cmd = "/usr/sbin/lhsmtool_posix --hsm_root=/tmp/backend --archive {archive_id} --rebind {oldfid} {newfid} {fsroot}";
}

lhsm_archive_parameters {
    nb_threads = 1;

    # limit archive rate to avoid flooding the MDT coordinator
    schedulers = common.rate_limit;
    rate_limit {
        # max count per period
        max_count = 1000;
        # max size per period: 1GB/s
        #max_size = 10GB;
        # period, in milliseconds: 10s
        period_ms = 10000;
    }

    # suspend policy run if action error rate > 50% (after 100 errors)
    suspend_error_pct = 50%;
    suspend_error_min= 100;

    # overrides policy default action
    action = cmd("lfs hsm_archive --archive {archive_id} /lustre/.lustre/fid/{fid}");

    # default action parameters
    action_params {
        archive_id = 1;
    }
}

lhsm_archive_rules {
    rule archive_small {
        target_fileclass = small_files;
        condition { last_mod >= 30min }
    }

    rule archive_std {
        target_fileclass = std_files;
        target_fileclass = big_files;
        condition { last_mod >= 30min }
    }

    # fallback rule
    rule default {
        condition { last_mod >= 30min }
    }
}

# run every 5 min
lhsm_archive_trigger {
    trigger_on = periodic;
    check_interval = 5min;
}

#### Lustre/HSM release configuration ####

lhsm_release_rules {
    # keep small files on disk as long as possible
    rule release_small {
        target_fileclass = small_files;
        condition { last_access > 1y }
    }

    rule release_std {
        target_fileclass = std_files;
        target_fileclass = big_files;
        condition { last_access > 1d }
    }

    # fallback rule
    rule default {
        condition { last_access > 6h }
    }
}

# run 'lhsm_release' on full OSTs
lhsm_release_trigger {
    trigger_on = ost_usage;
    high_threshold_pct = 85%;
    low_threshold_pct  = 80%;
    check_interval     = 5min;
}

lhsm_release_parameters {
    nb_threads = 4;
## purge 1000 files max at once
#    max_action_count = 1000;
#    max_action_volume = 1TB;

    # suspend policy run if action error rate > 50% (after 100 errors)
    suspend_error_pct = 50%;
    suspend_error_min= 100;
}

lhsm_remove_parameters
{
    # overrides policy default action
    action = cmd("/usr/sbin/lfs_hsm_remove.sh {fsroot} {fullpath} {archive_id} {fid}");

    # default action parameters
    action_params {
        archive_id = 1;
    } 
}

#### Lustre/HSM remove configuration ####
lhsm_remove_rules
{
    # cleanup backend files after 5m
    rule default {
        condition { rm_time >= 5m }
    }
}

# run daily
lhsm_remove_trigger
{
    trigger_on = periodic;
    check_interval = 5m;
}
EOF
chmod 600 $rbh_config_file


rbh_log_rotate_file="/etc/logrotate.d/robinhood"
cat <<EOF > $rbh_log_rotate_file
/var/log/robinhood*.log {
    compress
    weekly
    rotate 6
    notifempty
    missingok
}
EOF
chmod 644 $rbh_log_rotate_file


hsm_remove_script="/usr/sbin/lfs_hsm_remove.sh"
cat <<EOF > $hsm_remove_script
#!/bin/bash

fsroot="\$1"
fullpath="\$2"
archive_id="\$3"
fid="\$4"

lfs hsm_remove --data "{\"file_id\":\"\${fullpath#\${fsroot}/}\"}" --archive \${archive_id} --mntpath \${fsroot} \${fid}
EOF
chmod 755 $hsm_remove_script

systemctl enable robinhood
systemctl start robinhood

robinhood --scan --once


lustremetasync_systemd_file="/lib/systemd/system/lustremetasync.service"
cat <<EOF > $lustremetasync_systemd_file
[Unit]
Description=Handling directory/meta data backup on Lustre filesystem.
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
Environment="STORAGE_SAS=?$storage_sas"
ExecStart=/sbin/changelog-reader -account "$storage_account" -container "$storage_container" -mdt LustreFS-MDT0000 -userid cl2
Restart=always

[Install]
WantedBy=multi-user.target
EOF
chmod 600 $lustremetasync_systemd_file

systemctl enable lustremetasync
systemctl start lustremetasync
