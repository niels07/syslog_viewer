#!/bin/sh
#
# rotate_syslog.sh ~ script to create a new syslog table 
# and rename the old one
#

# For cronjobs
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/root/bin

# Name today's database based on date format.
DB_NAME=`date +%y-%m-%d`

# Password for root user.
ROOT_PASS="<PASS>" 

# Password for syslog user (logger)
USER_PASS="<PASS>"

mysqldump   -u root -p"$ROOT_PASS" syslog > backup.sql
mysql       -u root -p"$ROOT_PASS" -e "DROP DATABASE syslog; CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`"
mysql       -u root -p"$ROOT_PASS" "$DB_NAME" < backup.sql
rm backup.sql

mysql -u root -p$ROOT_PASS -e "
CREATE DATABASE IF NOT EXISTS syslog;
USE syslog;
CREATE TABLE IF NOT EXISTS logs (
    host varchar(255) default NULL,
    facility varchar(255) default NULL,
    priority varchar(255) default NULL,
    level varchar(255) default NULL,
    tag varchar(255) default NULL,
    datetime datetime default NULL,
    program varchar(255) default NULL,
    msg text,
    seq int(10) unsigned NOT NULL auto_increment,
    PRIMARY KEY (seq),
    KEY host (host),
    KEY seq (seq),
    KEY program (program),
    KEY datetime (datetime),
    KEY priority (priority),
    KEY facility (facility)
);
grant insert, select on syslog.* to logger@localhost identified by '$USER_PASS';
grant insert, select on \`$DB_NAME\`.* to logger@localhost identified by '$USER_PASS';"
exit $?
