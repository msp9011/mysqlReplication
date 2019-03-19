#!/bin/bash
# Date : 12-Dec-2018
# check README_Mysql_replication before running the script.


####### Provide the following details ####
MASTER1_IP=192.168.1.20
MASTER2_IP=192.168.1.21
SUBNET="192.168.1.%"
MASTER2_SSHUSER=root
MASTER2_SSHPASS="root123"
MASTER1_MYSQLUSER=root
MASTER2_MYSQLUSER=root
MASTER1_MYSQLPASS="abc123"
MASTER2_MYSQLPASS="abc123"
REPLUSER=Repli12
REPLPASS="repli@123"
DB1=abc
DB2=def
DB3=ghi
##########################################

SSHACCOUNT2="$MASTER2_SSHUSER"@"$MASTER2_IP"

sed -i '2i server-id  = 1'\\n'log-bin = /var/log/mysql/mysql-bin.log'\\n"binlog-do-db = $DB1  # input the database which should be replicated"\\n"binlog-do-db = $DB2"\\n"binlog-do-db = $DB3"\\n\\n'log_bin = /var/lib/mysql/binary-log/mysqld-bin'\\n'log_bin_index = /var/lib/mysql/binary-log/mysqld-bin'\\n'relay_log = /var/lib/mysql/binary-log/mysqld-relay-bin'\\n'expire_logs_days = 15'\\n'slave-skip-errors = 1062' /etc/my.cnf

BinaryLog="/var/lib/mysql/binary-log"
[ ! -d $BinaryLog ] &&  /bin/mkdir -p $BinaryLog
/bin/chown -R mysql:mysql $BinaryLog
#
/sbin/service mysqld restart 2>/dev/null


mysql "-u$MASTER1_MYSQLUSER" "-p$MASTER1_MYSQLPASS"  -e " 
        create user $REPLUSER@$MASTER1_IP identified by '$REPLPASS'; 
        create user $REPLUSER@$MASTER2_IP identified by '$REPLPASS';
        grant REPLICATION SLAVE on *.* to $REPLUSER@$MASTER1_IP identified by '$REPLPASS';
        grant REPLICATION SLAVE on *.* to $REPLUSER@$MASTER2_IP identified by '$REPLPASS';
        flush privileges;"

echo "flush sleep started"
mysql -u$MASTER1_MYSQLUSER -p$MASTER1_MYSQLPASS <<-EOSQL &
	FLUSH TABLES WITH READ LOCK;
	DO SLEEP(600);
EOSQL

sleep 3
#
sshpass -p "$MASTER2_SSHPASS" ssh -tt $SSHACCOUNT2  "sed -i '2i server-id  = 2' /etc/my.cnf
sed -i '3i log-bin = /var/log/mysql/mysql-bin.log' /etc/my.cnf
sed -i '4i binlog-do-db = $DB1' /etc/my.cnf
sed -i '5i binlog-do-db = $DB2' /etc/my.cnf
sed -i '6i binlog-do-db = $DB3' /etc/my.cnf
sed -i '7i log_bin = /var/lib/mysql/binary-log/mysqld-bin' /etc/my.cnf
sed -i '8i log_bin_index = /var/lib/mysql/binary-log/mysqld-bin' /etc/my.cnf
sed -i '9i relay_log = /var/lib/mysql/binary-log/mysqld-relay-bin' /etc/my.cnf
sed -i '10i expire_logs_days = 15' /etc/my.cnf
sed -i '11i slave-skip-errors = 1062' /etc/my.cnf"

mysql -h $MASTER2_IP  "-u$MASTER2_MYSQLUSER" "-p$MASTER2_MYSQLPASS" -e " 
        create user $REPLUSER@$MASTER1_IP identified by '$REPLPASS'; 
        create user $REPLUSER@$MASTER2_IP identified by '$REPLPASS';
        grant REPLICATION SLAVE on *.* to $REPLUSER@$MASTER1_IP identified by '$REPLPASS';
        grant REPLICATION SLAVE on *.* to $REPLUSER@$MASTER2_IP identified by '$REPLPASS';
        flush privileges;"

sshpass -p "$MASTER2_SSHPASS" ssh -tt $SSHACCOUNT2  "[ ! -d $BinaryLog ] &&  /bin/mkdir -p $BinaryLog && chown -R mysql:mysql $BinaryLog"


sshpass -p "$MASTER2_SSHPASS" rsync -az -e 'ssh -p 22' /var/lib/mysql/"$DB1" "$SSHACCOUNT2":/var/lib/mysql/
sshpass -p "$MASTER2_SSHPASS" rsync -az -e 'ssh -p 22' /var/lib/mysql/"$DB2" "$SSHACCOUNT2":/var/lib/mysql/
sshpass -p "$MASTER2_SSHPASS" rsync -az -e 'ssh -p 22' /var/lib/mysql/"$DB3" "$SSHACCOUNT2":/var/lib/mysql/

echo " sync done"

sshpass -p "$MASTER2_SSHPASS" ssh -tt $SSHACCOUNT2 "chown mysql:mysql -R /var/lib/mysql/"
sshpass -p "$MASTER2_SSHPASS" ssh -tt $SSHACCOUNT2 "service mysqld restart"

MASTER_STATUS=$(mysql "-u$MASTER1_MYSQLUSER" "-p$MASTER1_MYSQLPASS" -e "SHOW MASTER STATUS;" | awk '/mysql/ {print $1 " " $2}')
LOG1_FILE=$(echo $MASTER_STATUS | cut -f1 -d ' ')
LOG1_POS=$(echo $MASTER_STATUS | cut -f2 -d ' ')

echo "$MASTER1_IP : Log file is $LOG1_FILE and log position is $LOG1_POS"
echo "  - Setting up MASTER2_ replication"
mysql -h $MASTER2_IP "-u$MASTER2_MYSQLUSER" "-p$MASTER2_MYSQLPASS"  -e "STOP SLAVE;"
mysql -h $MASTER2_IP "-u$MASTER2_MYSQLUSER" "-p$MASTER2_MYSQLPASS"  -e "CHANGE MASTER TO MASTER_HOST = '$MASTER1_IP', MASTER_USER = '$REPLUSER', MASTER_PASSWORD = '$REPLPASS', MASTER_LOG_FILE = '$LOG1_FILE', MASTER_LOG_POS = $LOG1_POS; "
mysql -h $MASTER2_IP "-u$MASTER2_MYSQLUSER" "-p$MASTER2_MYSQLPASS"  -e "START SLAVE;"

MASTER_STATUS=$(mysql -h $MASTER2_IP "-u$MASTER2_MYSQLUSER" "-p$MASTER2_MYSQLPASS" -e "SHOW MASTER STATUS;" | awk '/mysql/ {print $1 " " $2}')
LOG2_FILE=$(echo $MASTER_STATUS | cut -f1 -d ' ')
LOG2_POS=$(echo $MASTER_STATUS | cut -f2 -d ' ')

echo "$MASTER2_IP : Log file is $LOG2_FILE and log position is $LOG2_POS"

mysql -u$MASTER1_MYSQLUSER -p$MASTER1_MYSQLPASS -e "UNLOCK TABLES;"
SLEEP_ID=(`mysql -u$MASTER1_MYSQLUSER -p$MASTER1_MYSQLPASS -e "SELECT id FROM information_schema.processlist where Command = 'Sleep' and DB IS NULL;"`)
for SleepId in ${SLEEP_ID[@]}
	mysql -u$MASTER1_MYSQLUSER -p$MASTER1_MYSQLPASS -e "Kill $SleepId;"
do

echo "  - Setting up MASTER1_ replication"
mysql "-u$MASTER1_MYSQLUSER" "-p$MASTER1_MYSQLPASS"  -e "STOP SLAVE;"
mysql "-u$MASTER1_MYSQLUSER" "-p$MASTER1_MYSQLPASS"  -e "CHANGE MASTER TO MASTER_HOST = '$MASTER2_IP', MASTER_USER = '$REPLUSER', MASTER_PASSWORD = '$REPLPASS', MASTER_LOG_FILE = '$LOG2_FILE', MASTER_LOG_POS = $LOG2_POS; "
mysql "-u$MASTER1_MYSQLUSER" "-p$MASTER1_MYSQLPASS"  -e "START SLAVE;"
