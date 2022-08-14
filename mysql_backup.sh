#!/bin/bash 

#this script will create a Full Backup every night at 12:00 from Controller Database and create incremental Backup every other hour.

#calculating date and time
today=`date +%Y%m%d`
now=`date +%H`
yesterday=`date -d "yesterday" '+%Y%m%d'`

# define a destination for Daily Full Backup and create it if it doesn't exist.
full_dir="/root/daily_backup/$today/Full"
inc_dir="/root/daily_backup/$today/Incremental/$now"

if [ ! -d /root/daily_backup/$today ] ;
then
        mkdir -p /root/daily_backup/$today
        mkdir -p /root/daily_backup/$today/Full
        mkdir -p /root/daily_backup/$today/Incremental
fi

#check the time, if it is midnight it means this is the first launch, so just make the Full Backup. 
#but if the time passed the midnight so try to make incremental backups.
if [ $now == "00" ];
then
        echo "Creating full backup for $today " >> /root/database_backup.log
        mariabackup --backup --target-dir=$full_dir --user=root 1>/dev/null 2>&1
        if [ $? != 0 ];
        then
                echo "Failed to Create Full Backup for $today " >> /root/database_backup.log 
        fi

#then compress yesterday's backup and scp to the backup server.
        echo "compressing $yesterday backup " >> /root/database_backup.log
        tar czf /root/daily_backup/$yesterday.tar.gz /root/daily_backup/$yesterday 1>/dev/null 2>&1
        if [ $? != 0 ];
        then
                echo "Failed to Compress $yesterday backup" >> /root/database_backup.log
        fi

        echo "sending $yesterday backup to Backup_Server (192.168.169.115)" >> /root/database_backup.log
        scp /root/daily_backup/$yesterday.tar.gz root@192.168.169.115:/controllers_database/ 1>/dev/null 2>&1
        if [ $? != 0 ];
        then
                echo "Failed to send $yesterday backup to Backup_Server" >> /root/database_backup.log
        fi

#now, just delete the backups older than 5 days from "controller server"
        echo "Deleting Backups older than 5 days from this server" >> /root/database_backup.log
        find /root/daily_backup/   -mtime +5  -exec rm -f {} \;
else
        echo "Creating Incremental backup for $today-$now">> /root/database_backup.log
        mkdir -p /root/daily_backup/$today/Incremental/$now
        mariabackup --backup --target-dir=$inc_dir --incremental-basedir=$full_dir --user=root 1>/dev/null 2>&1
        if [ $? != 0 ];
        then
                echo "Failed to make Incremental backup for $today-$now" >> /root/database_backup.log
        fi

fi
if [ $now == "23"  ];
then
        echo "====================================================================" >> /root/database_backup.log 
fi
