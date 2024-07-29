#! /bin/sh
#***********************************************
#*                forcestop.sh                 *
#*                                             *
#* Sample force stop script for Guest OS       *
#*           Cluster for Linux on Proxmox VE.  *
#*                                             *
#* Assumption:                                 *
#*  - All cluster nodes are managed by one     *
#*    Proxmox VE Server.                       *
#*  - Each cluster nodes hostname is same as   *
#*    each VM name.                            *
#*  - All cluster nodes have the following     *
#*    software.                                *
#*    - python3                                *
#*    - awk                                    *
#*    - curl                                   *
#***********************************************


# Configuration:
# change the following values according your environment

PVE_HOST_NODENAME=<e.g. pvenode1>
PVE_HOST_ENDPOINT=<e.g. 192.168.10.200:8006>
PVE_HOST_USERNAME=<e.g. root@pam>
PVE_HOST_PASSWORD=<e.g. mypassword>

CLUSTER_NODE1_NAME=<e.g. node1>
CLUSTER_NODE1_VMID=<e.g. 101>
CLUSTER_NODE2_NAME=<e.g. node2>
CLUSTER_NODE2_VMID=<e.g. 102>
# If you have more cluster nodes, add pairs of a name and a vmid like above


# Constants

JSON_PARSER_COMMAND="python3 -m json.tool"
FORCESTOP_LOGFILE=/tmp/clpforcestop.log

PVE_RESTAPI_TICKET=/api2/json/access/ticket
PVE_RESTAPI_QEMU=/api2/json/nodes/$PVE_HOST_NODENAME/qemu
PVE_RESTAPI_STATUS_CURRENT=/status/current
PVE_RESTAPI_STATUS_STOP=/status/stop
PVE_RESTAPI_STATUS_RESET=/status/reset
PVE_TICKET_TMPFILE=/tmp/pve-ticket.json


# Functions

function set_target_vmid() {
    local nodename=$1

    if [ $nodename = $CLUSTER_NODE1_NAME ]; then
        TARGET_VMID=$CLUSTER_NODE1_VMID
    elif [ $nodename = $CLUSTER_NODE2_NAME ]; then
        TARGET_VMID=$CLUSTER_NODE2_VMID
    else
        #echo "Unknown node name ($nodename)" >> $FORCESTOP_LOGFILE
        :
    fi
}

function pve_login() {
    curl -s -k -d "username=$PVE_HOST_USERNAME" \
         --data-urlencode "password=$PVE_HOST_PASSWORD" \
         https://${PVE_HOST_ENDPOINT}${PVE_RESTAPI_TICKET} \
         > $PVE_TICKET_TMPFILE

    PVE_TICKET=`$JSON_PARSER_COMMAND < $PVE_TICKET_TMPFILE \
        | awk '/ticket/ {gsub(/[,"]/, "", $2); print $2}'`

    PVE_CSRF_TOKEN=`$JSON_PARSER_COMMAND < $PVE_TICKET_TMPFILE \
        | awk '/CSRFPreventionToken/ {gsub(/[,"]/, "", $2); print $2}'`

    #echo "PVE_TICKET:     $PVE_TICKET" >> $FORCESTOP_LOGFILE
    #echo "PVE_CSRF_TOKEN: $PVE_CSRF_TOKEN" >> $FORCESTOP_LOGFILE

    rm -f $PVE_TICKET_TMPFILE
}

function pve_check_status() {
    curl -s -X GET -k -b "PVEAuthCookie=$PVE_TICKET" \
         https://${PVE_HOST_ENDPOINT}${PVE_RESTAPI_QEMU}/${TARGET_VMID}${PVE_RESTAPI_STATUS_CURRENT} \
        | $JSON_PARSER_COMMAND \
        | awk '/"status"/ {print $2}' \
        | grep "running"

    if [ $? -eq 0 ]; then
        #echo "check: OK" >> $FORCESTOP_LOGFILE
        exit 0
    else
        #echo "check: NG" >> $FORCESTOP_LOGFILE
        exit 1
    fi
}

function pve_vm_stop() {
    curl -s -X POST -k -b "PVEAuthCookie=$PVE_TICKET" \
         -H "CSRFPreventionToken: $PVE_CSRF_TOKEN" \
         https://${PVE_HOST_ENDPOINT}${PVE_RESTAPI_QEMU}/${TARGET_VMID}${PVE_RESTAPI_STATUS_STOP} \
        | $JSON_PARSER_COMMAND \
        | grep "qmstop"

    if [ $? -eq 0 ]; then
        #echo "vm_stop: OK" >> $FORCESTOP_LOGFILE
        :
    else
        #echo "vm_stop: NG" >> $FORCESTOP_LOGFILE
        exit 1
    fi

    for i in {1..5}; do
        curl -s -X GET -k -b "PVEAuthCookie=$PVE_TICKET" \
             https://${PVE_HOST_ENDPOINT}${PVE_RESTAPI_QEMU}/${TARGET_VMID}${PVE_RESTAPI_STATUS_CURRENT} \
            | $JSON_PARSER_COMMAND \
            | awk '/"status"/ {print $2}' \
            | grep "stopped"

        if [ $? -eq 0 ]; then
            #echo "vm_status: stopped" >> $FORCESTOP_LOGFILE
            exit 0
        else
            #echo "vm_status: not stopped" >> $FORCESTOP_LOGFILE
            :
        fi
        sleep 2
    done

    #echo "failed to confirm that vm has been stopped" >> $FORCESTOP_LOGFILE
    exit 1
}


# Main process

pve_login

if [ $CLP_FORCESTOP_MODE -eq 0 ]; then
    # check REST API availability
    set_target_vmid $CLP_SERVER_LOCAL
    pve_check_status
elif [ $CLP_FORCESTOP_MODE -eq 1 ]; then
    # forcibly stop (or reset) the target node
    set_target_vmid $CLP_SERVER_DOWN
    pve_vm_stop
else
    #echo "Unknown mode ($CLP_FORCESTOP_MODE)" >> $FORCESTOP_LOGFILE
    exit 1
fi
