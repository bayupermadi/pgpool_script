#!/bin/bash
# By Bayu Permadi, 17/08/2017
# Recovers a standby server.
 
if [ $# -ne 5 ]
then
    echo "failover falling_node oldprimary_node new_primary replication_password trigger_file"
    exit 1
fi
 
FALLING_NODE=$1         # %d
OLDPRIMARY_NODE=$2      # %P
NEW_PRIMARY=$3          # %H
REPL_PASS=$4
TRIGGER_FILE=$5
 
echo "failover.sh FALLING_NODE: ${FALLING_NODE}; OLDPRIMARY_NODE: ${OLDPRIMARY_NODE}; NEW_PRIMARY: ${NEW_PRIMARY}; at $(date)\n" >> /etc/postgresql/9.5/main/replscripts/exec.log
 
if [ $FALLING_NODE = $OLDPRIMARY_NODE ]; then
    ssh -T failover@$NEW_PRIMARY sudo touch /var/lib/pgsql/9.6/data/$TRIGGER_FILE
    ssh -T failover@$OLDPRIMARY_NODE sudo systemctl stop postgresql-9.6
    exit 0;
fi;
 
exit 0;