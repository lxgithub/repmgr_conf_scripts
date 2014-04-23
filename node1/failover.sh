#!/bin/bash
# Created by lianshunke@highgo.com.cn 2014/04/16
# Do
#   1.Promote the standby.
#   2.Change the pgbouncer.ini on pgbouncer-server.
#   3.Restart the pgbouncer.ini on pgbouncer-server.

PGHOME=/opt/pgsql
PGBIN=$PGHOME/bin
PGDATA=$PGHOME/data
PGPORT=5432
PGUSER=postgres

LOG_FILE=/opt/pgsql/repmgr/failover.log

BOUN_SERVER=witness
BOUN_FILE=/opt/pgbouncer/pgbouncer.ini
BOUN_LISTEN_PORT=6432
BOUN_ADMIN_USER=pgbouncer

# STANDBY_IP = FAIL_NODE_IP
STANDBY_IP=192.168.100.*
# MASTER_IP = LOCAL_IP
MASTER_IP=192.168.100.146
CONN_INFO="user=postgres port=5432 dbname=postgres"

TIME=`date '+%Y-%m-%d %H:%M:%S'`
echo -n "$TIME " >> $LOG_FILE
$PGBIN/pg_ctl -D $PGDATA promote >> $LOG_FILE
if [ $? == 0 ];then
  IF_RECOVERY=" t"
  while [ "$IF_RECOVERY" = " t" ];do
  TIME=`date '+%Y-%m-%d %H:%M:%S'`
  IF_RECOVERY=`psql -c "select pg_is_in_recovery()" | sed -n '3,3p'`
  if [ "$IF_RECOVERY" = " f" ];then
    echo "$TIME FAILOVER-INFO: promote successful!" >> $LOG_FILE
    TIME=`date '+%Y-%m-%d %H:%M:%S'`
    echo "sed -i 's/host=$STANDBY_IP/host=$MASTER_IP $CONN_INFO/g' $BOUN_FILE" | ssh $PGUSER@$BOUN_SERVER bash
    if [ $? == 0 ];then
      echo "$TIME FAILVOER-INFO: change pgbouncer.ini successful!" >> $LOG_FILE
#     $PGBIN/psql -h $BOUN_SERVER -p $BOUN_LISTEN_PORT -U $BOUN_ADMIN_USER pgbouncer -c "reload" > /dev/null
#      TIME=`date '+%Y-%m-%d %H:%M:%S'`
#      echo "$TIME " >> $LOG_FILE
      ssh postgres@witness ". ~/.bash_profile;pgbouncer -R -d $BOUN_FILE" &>> $LOG_FILE
      if [ $? == 0 ];then
        TIME=`date '+%Y-%m-%d %H:%M:%S'`
        echo "$TIME FAILOVER-INFO: pgbouncer reload successful!" >> $LOG_FILE
        echo "################################# The New Conn_info ####################################" >> $LOG_FILE
        # Ensure the auth_type = trust
        $PGBIN/psql -h $BOUN_SERVER -p $BOUN_LISTEN_PORT -U $BOUN_ADMIN_USER pgbouncer -c "show databases" >> $LOG_FILE
        echo "########################################################################################" >> $LOG_FILE
      else
        echo "$TIME FAILOVER-ERROR: pgbouncer reload failed!" >> $LOG_FILE
      fi
    else
      echo "$TIME FAILOVER-ERROR: change pgbouncer.ini failed!" >> $LOG_FILE
    fi
  else
    echo "$TIME FAILOVER-ERROR: the db is still in recovery! Sleep 1s and Retry..." >> $LOG_FILE
    sleep 1
  fi
  done
else
  echo "$TIME ERROR: promote failed!"
fi
