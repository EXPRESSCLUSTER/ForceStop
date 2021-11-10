#! /bin/sh
#***********************************************
#*                forcestop.sh                 *
#*                                             *
#* Sample force stop script for Guest OS       *
#*  Cluster for Linux.                         *
#* Assumption:                                 *
#*  - All cluster nodes are managed by one     *
#*    vCenter Server.                          *
#*  - Each cluster nodes hostname is same as   *
#*    each VM name.                            *
#***********************************************

VC_USERNAME=<vCenter Server login user name (e.g. administrator@vsphere.local)>
VC_PASSWORD=<vCenter Server login password>
VC_IP=<vCenter Server IP address or hostname (if Name Resolution works)>"
CREATE_SESSION_RETRY=3
SHUTDOWN_RETRY=3


TARGET_HOSTNAME=${CLP_SERVER_DOWN}

# Functin to return txt with JSON format
function return_json_format () {
	JSON=`echo $1 | sed -e 's/,/,\n/g' | sed -e 's/{/{\n/g' | sed -e 's/}/}\n/g' | sed -e 's/\[/\[\n/g' | sed -e 's/\]/\]\n/g'`
	echo "$JSON"
	return 0
}

# Function to return value in JSON
function return_json_value () {
	echo "$1" | while read line
	do
		LABEL=`echo $line | awk -F: '{print $1}' | awk -F\" '{print $2}'`
		if [ "$LABEL" = "$2" ];
		then
			echo $line | awk -F: '{print $2}' | awk -F\" '{print $2}'
		fi
	done
	return 0
}

# Start main

# Create session with vCenter Server
COUNT=0
while [ $COUNT -lt $CREATE_SESSION_RETRY ]
do
	let COUNT=${COUNT}+1

	# Create session
	OUTPUT=`curl -sS -k -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "vmware-api-session-id: null" --user "${VC_USERNAME}:${VC_PASSWORD}" "https://${VC_IP}/rest/com/vmware/cis/session" 2>&1`
	RESULT=$?
	if [ $RESULT -ne 0 ];
	then
                echo "Failed to connect vCenter Server (Create Session):"
                echo "$OUTPUT"
                echo "Exit code: ${RESULT}"
		continue
	fi

	# Check returned session ID
	OUTPUT=`return_json_format "$OUTPUT"`
	SESSION_ID=`return_json_value "$OUTPUT" "value"`
	if [ -z "$SESSION_ID" ];
	then
                echo "Failed to get session ID:"
                echo "$OUTPUT"
                RESULT=1
		continue
	else
		break
	fi
done

if [ $RESULT -ne 0 ];
then
	echo "Force stop failure. (Create session)"
	exit $RESULT
fi

# Shutdown target vm
COUNT=0
while [ $COUNT -lt $SHUTDOWN_RETRY ]
do
	let COUNT=${COUNT}+1

	# Get target VM ID and power status
	OUTPUT=`curl -sS -k -X GET "https://${VC_IP}/rest/vcenter/vm?filter.names=${TARGET_HOSTNAME}" -H "vmware-api-session-id: ${SESSION_ID}"`
	RESULT=$?
	if [ $RESULT -ne 0 ];
	then
		echo "Failed to connect to vCenter Server (Get VM Parameters):"
		echo "$OUTPUT"
		echo "Exit code: ${RESULT}"
		continue
	fi

	# Check returned target VM ID
	OUTPUT=`return_json_format "$OUTPUT"`
	TARGET_VM_ID=`return_json_value "$OUTPUT" "vm"`
	if [ -z "$TARGET_VM_ID" ];
	then
		echo "Failed to get target VM ID:"
		echo "$OUTPUT"
		RESULT=1
		continue
	fi

	# Check returned target VM power status
	TARGET_VM_STATUS=`return_json_value "$OUTPUT" "power_state"`
	if [ "$TARGET_VM_STATUS" = "POWERED_OFF" ];
	then
		echo "Target VM has already been powered off:"
		echo "$OUTPUT"
		exit 0
	fi

	# Shutdown target VM
	OUTPUT=`curl -sS -k -X POST "https://${VC_IP}/rest/vcenter/vm/${TARGET_VM_ID}/power/stop" -H "vmware-api-session-id: ${SESSION_ID}"`
	RESULT=$?
	if [ $RESULT -ne 0 ];
	then
		echo "Failed to connect to vCenter Server (Shutdown target VM):"
		echo "$OUTPUT"
		echo "Exit code: $RESULT"
		continue
	fi

	# Get target VM power status
	OUTPUT=`curl -sS -k -X GET "https://${VC_IP}/rest/vcenter/vm/${TARGET_VM_ID}/power" -H "vmware-api-session-id: ${SESSION_ID}"`
	RESULT=$?
	if [ $RESULT -ne 0 ];
	then
		echo "Failed to connect to vCenter Server (Check target VM power status)."
		echo "$OUTPUT"
		echo "Exit code: $RESULT"
		continue
	fi

	# Check returned target VM power status
	OUTPUT=`return_json_format "$OUTPUT"`
	TARGET_VM_STATUS=`return_json_value "$OUTPUT" "state"`
	if [ "$TARGET_VM_STATUS" != "POWERED_OFF" ];
	then
		echo "Failed to power off target VM:"
		echo "$OUTPUT"
		RESULT=1
		continue
	else
		echo "Succeeded to power off:"
		echo "$OUTPUT"
		exit 0
	fi
done

echo "Force stop failure. (Power off)"
exit $RESULT
