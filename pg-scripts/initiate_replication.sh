#!/bin/sh
# By Bayu Permadi, 17/08/2017
# Promoting standby to primary node.
# NOTE: The script should be executed as postgres user
 
echo "initiate_replication - Start"
 
# Defining default values
primary_host=""
primary_port="5432"
slot_name=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
slot_name=${slot_name/-/_}
replication_user="replication"
replication_password="123456"
 
debug=true
 
while test $# -gt 0; do
 
    case "$1" in
 
        -h|--help)
             
            echo "Promotes a standby server to primary role"
            echo " "
            echo "promote [options]"
            echo " "
            echo "options:"
            echo "-h, --help                show brief help"
            echo "-H, --primary-host=HOST   specify primary host (Mandatory)"
            echo "-P, --primary-port=PORT   specify primary port"
            echo "    Optional, default: 5432"
            echo "-n, --slot_name=NAME      specify slot name"
            echo "    Optional, defaults to lowercase hostname with dashes replaced"
            echo "                          by underscores."
            echo "-u, --user                specify replication role"
            echo "    Optional, default: replication"
            echo "-p, --password=PASSWORD   specify password for --user"
            echo "    Optional, default: empty"
            echo " "
            echo "Error Codes:"
            echo "  2 - Argument error. Caused either by bad format of provided flags and"
            echo "      arguments or if a mandatory argument is missing."
            echo "  5 - Error in communicating with the primary server (to create the"
            echo "      slot or get the initial data)."
            echo "  6 - Error deleting old data directory."
            exit 0
            ;;
 
        -H)
 
            shift
 
            if test $# -gt 0; then
 
                primary_host=$1
 
            else
 
                echo "ERROR: -H flag requires primary host to be specified."
                exit 2
 
            fi
 
            shift
            ;;
 
        --primary-host=*)
 
            primary_host=`echo $1 | sed -e 's/^[^=]*=//g'`
 
            shift
            ;;
 
        -P)
 
            shift
 
            if test $# -gt 0; then
 
                primary_port=$1
 
            else
 
                echo "ERROR: -p flag requires port to be specified."
                exit 2
 
            fi
 
            shift
            ;;
 
        --primary-port=*)
 
            primary_port=`echo $1 | sed -e 's/^[^=]*=//g'`
 
            shift
            ;;
 
        -n)
 
            shift
 
            if test $# -gt 0; then
 
                slot_name=$1
 
            else
 
                echo "ERROR: -n flag requires slot name to be specified."
                exit 2
 
            fi
 
            shift
            ;;
 
        --slot-name=*)
 
            slot_name=`echo $1 | sed -e 's/^[^=]*=//g'`
 
            shift
            ;;
 
        -u)
 
            shift
 
            if test $# -gt 0; then
 
                replication_user=$1
 
            else
 
                echo "ERROR: -u flag requires replication user to be specified."
                exit 2
 
            fi
 
            shift
            ;;
 
        --user=*)
 
            replication_user=`echo $1 | sed -e 's/^[^=]*=//g'`
 
            shift
            ;;
 
        -p)
 
            shift
 
            if test $# -gt 0; then
 
                replication_password=$1
 
            else
 
                echo "ERROR: -p flag requires replication password to be specified."
                exit 2
 
            fi
 
            shift
            ;;
 
        --password=*)
 
            replication_password=`echo $1 | sed -e 's/^[^=]*=//g'`
 
            shift
            ;;
        *)
 
            echo "ERROR: Unrecognized option $1"
            exit 2
            ;;
 
    esac
 
done
 
if [ "$primary_host" = "" ]; then
 
    echo "ERROR: Primary host is mandatory. For help execute 'initiate_replication -h'"
    exit 2
 
fi
 
if [ "$replication_password" = "" ]; then
 
    echo "ERROR: --password is mandatory. For help execute 'initiate_replication -h'"
    exit 2
 
fi
 
if $debug; then
 
    echo "DEBUG: The script will be executed with the following arguments:"
    echo "DEBUG: --primary-host=$primary_host"
    echo "DEBUG: --primary-port=$primary_port"
    echo "DEBUG: --slot-name=$slot_name"
    echo "DEBUG: --user=$replication_user"
    echo "DEBUG: --password=$replication_password"
 
fi
 
echo "INFO: Ensuring replication user and password in password file (.pgpass)..."
password_line="*:*:*:${replication_user}:${replication_password}"
 
if [ ! -f /var/lib/pgsql/.pgpass ]; then
 
    echo $password_line > /var/lib/pgsql/.pgpass
 
elif ! grep -q "$password_line" /var/lib/pgsql/.pgpass ; then
 
    sed -i -e '$a\' /var/lib/pgsql/.pgpass
    echo $password_line > /var/lib/pgsql/.pgpass
    sed -i -e '$a\' /var/lib/pgsql/.pgpass
 
fi
 
chown postgres:postgres /var/lib/pgsql/.pgpass
chmod 0600 /var/lib/pgsql/.pgpass
 
success=false
 
echo "INFO: Creating replication slot at the primary server..."
ssh -T failover@$primary_host sudo /opt/postgresql/create_slot.sh -r $slot_name && success=true
 
if ! $success ; then
 
    echo "ERROR: Creating replication slot at the primary server failed."
    exit 5
 
fi
 
sudo systemctl stop postgresql-9.6
 
if [ -d /var/lib/pgsql/9.6/data ]; then
 
    echo "INFO: Deleting old data..."
 
    success=false      
    sudo -u postgres rm -rf /var/lib/pgsql/9.6/data && success=true
 
    if ! $success ; then
 
        echo "ERROR: Deleting data directory failed."
        exit 6
 
    fi
 
fi
 
echo "INFO: Getting the initial backup..."
 
success=false
sudo -u postgres /usr/pgsql-9.6/bin/pg_basebackup -D /var/lib/pgsql/9.6/data -h $primary_host -p $primary_port -U $replication_user && success=true
 
if ! $success; then
 
    echo "ERROR: Initial backup failed."
    exit 5
 
fi
 
if [ -e /var/lib/pgsql/9.6/data/recovery.conf ]; then
 
    echo "INFO: Removing old recovery file..."
 
    success=false
    sudo -u postgres rm /var/lib/pgsql/9.6/data/recovery.conf && success=true
    sudo -u postgres rm /var/lib/pgsql/9.6/data/recovery.done && success=true
 
    if ! $success; then
 
        echo "ERROR: Removing old recovery file failed."
        exit 4
 
    fi
 
fi
 
echo "INFO: Creating recovery.conf file..."
sudo -u postgres cat >/var/lib/pgsql/9.6/data/recovery.conf <<EOL
standby_mode       = 'on'
primary_slot_name  = '${slot_name}'
primary_conninfo   = 'host=${primary_host} port=${primary_port} user=${replication_user} password=${replication_password}'
trigger_file       = '${trigger_file}'
EOL
 

echo "INFO: Starting postgresql service..."
sudo systemctl start postgresql-9.6 
sudo systemctl is-active postgresql-9.6
 
echo "initiate_replication - Done!"
exit 0