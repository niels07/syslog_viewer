#!/bin/sh
name=`date +%y-%m-%d`
pass="<PASS>" 

mysqldump   -u root -p$pass syslog > backup.sql
mysql       -u root -p$pass -e "DROP DATABASE syslog; CREATE DATABASE \`$name\`"
mysql       -u root -p$pass "$name" < backup.sql
rm backup.sql

mysql -u root -p$pass -e "
CREATE DATABASE syslog;
USE syslog;
CREATE TABLE logs (
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
grant insert, select on syslog.* to logger@localhost identified by '<PASS>';
grant insert, select on \`$name\`.* to logger@localhost identified by '<PASS>';"
exit $?
