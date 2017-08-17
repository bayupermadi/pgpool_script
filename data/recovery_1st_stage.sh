#!/bin/bash
# By Bayu Permadi, 17/08/2017
# Recovers a standby server.
 
if [ $# -ne 3 ]
then
    echo "recovery_1st_stage datadir remote_host remote_datadir"
    exit 1
fi
 
PGDATA=$1
REMOTE_HOST=$2
REMOTE_PGDATA=$3
 
PORT=5432
 
echo "recovery_1st_stage.sh - PGDATA: ${PGDATA}; REMOTE_HOST: ${REMOTE_HOST}; REMOTE_PGDATA: ${REMOTE_PGDATA}; at $(date)\n" >> /var/lib/pgsql/9.6/data/pg_log/exec.log
 
hostnamelower=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
remotelower=$(echo "$REMOTE_HOST" | tr '[:upper:]' '[:lower:]')
 
if [ "$hostnamelower" = "$remotelower" ]; then
    echo "Cannot recover myself."
    exit 1
fi
 
ssh -T failover@$REMOTE_HOST  sudo /opt/postgresql/initiate_replication.sh -H $HOSTNAME -P $PORT
 
exit 0;