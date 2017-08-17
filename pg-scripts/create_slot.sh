#!/bin/sh
# By Bayu Permadi, 17/08/2017
# (Re)creates replication slot.
# NOTE: The script should be executed as postgres user
 
echo "create_slot - Start"
 
# Defining default values
slot_name=""
recreate=false
 
debug=true
 
while test $# -gt 0; do
 
    case "$1" in
 
        -h|--help)
 
            echo "Creates replication slot"
            echo " "
            echo "create_slot [options]"
            echo " "
            echo "options:"
            echo "-h, --help                show brief help"
            echo "-n, --name=NAME           slot name (mandatory)"
            echo "                          Slot name can be also specified without using"
            echo "                          flags (i.e. 'create_slot myslot')"
            echo "-r, --recreate            Forces re-creation if the slot already exists"
            echo "    Optional, default: N/A"
            echo "    Description:       Without this flag the script won't do anything if"
            echo "                       the slot with defined name already exists."
            echo "                       With the flag set, if the slot with defined name"
            echo "                       already exists it will be deleted and re-created."
            echo " "
            echo "Error Codes:"
            echo "  2 - Argument error. Caused either by bad format of provided flags and"
            echo "      arguments or if a mandatory argument is missing."
            echo "  4 - Error executing a slot-related operation (query/create/drop)."
            exit 0
            ;;
 
        -n)
         
            if [ "$slot_name" != "" ]; then
         
                echo "ERROR: Invalid command. For help execute 'create_slot -h'"
                exit 2
         
            fi
             
            shift
         
            if test $# -gt 0; then
         
                slot_name=$1
             
            else
             
                echo "ERROR: -n flag requires slot name to be specified."
                exit 2
             
            fi
             
            shift
            ;;
 
        --name=*)
             
            if [ "$slot_name" != "" ]; then
             
                echo "ERROR: Invalid command. For help execute 'create_slot -h'"
                exit 2
             
            fi
             
            slot_name=`echo $1 | sed -e 's/^[^=]*=//g'`
             
            shift
            ;;
 
        -r|--recreate)
 
            recreate=true
 
            shift
            ;;
 
        *)
 
            if [ "$slot_name" != "" ]; then
                 
                echo "ERROR: Invalid command. For help execute 'create_slot -h'"
                exit 2
             
            fi
             
            slot_name=$1
             
            shift
            ;;
 
    esac
 
done
 
if [ "$slot_name" = "" ]; then
 
    echo "ERROR: Slot name is mandatory. For help execute 'create_slot -h'"
    exit 2
 
fi
 
if $debug; then
 
    echo "DEBUG: The script will be executed with the following arguments:"
    echo "DEBUG: --name=${slot_name}"
     
    if $recreate; then
        echo "DEBUG: --recreate"
    fi
     
fi
 
success=false
 
echo "INFO: Checking if slot '${slot_name}' exists..."
slotcount=$(sudo -u postgres psql -Atc "SELECT count (*) FROM pg_replication_slots WHERE slot_name='${slot_name}';") && success=true
 
if ! $success ; then
 
    echo "ERROR: Cannot check for '${slot_name}' slot existence."
    exit 4
 
fi
 
if [ "$slotcount" = "0" ]; then
 
    echo "INFO: Slot not found. Creating..."
 
    success=false
    sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('${slot_name}');" && success=true
         
    if ! $success ; then
 
        echo "ERROR: Cannot create '${slot_name}' slot."
        exit 4
 
    fi
 
elif $recreate ; then
 
    echo "INFO: Slot found. Removing..."
 
    success=false
    sudo -u postgres psql -c "SELECT pg_drop_replication_slot('${slot_name}');" && success=true
     
    if ! $success ; then
 
        echo "ERROR: Cannot drop existing '${slot_name}' slot."
        exit 4
 
    fi
 
    echo "INFO: Re-creating the slot..."
 
    success=false
    sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('${slot_name}');" && success=true
     
    if ! $success ; then
 
        echo "ERROR: Cannot create '${slot_name}' slot."
        exit 4
 
    fi
 
fi
 
echo "create_slot - Done!"
exit 0