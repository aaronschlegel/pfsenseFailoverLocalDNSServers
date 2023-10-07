#!/bin/bash

# Validate that we got the correct number of arguments
if [ "$#" -ne 9 ]; then
    echo "Usage: $0 <DNS1_IP> <DNS2_IP> <TEST_DOMAIN> <EXPECTED_IP> <RULE_ID1> <RULE_ID2> <RULE_ID3> <RULE_ID4> <SECONDS_DELAY>"
    exit 1
fi

# State file path
STATE_FILE="/tmp/dns_failed_state"

# Log file and its maximum size
LOGFILE="/var/log/dns_failover_check.log"
MAX_LOG_SIZE=1024000  # 1MB

# Rotate log if it exceeds the max size
if [[ -f "$LOGFILE" && $(stat -f "%z" "$LOGFILE") -ge $MAX_LOG_SIZE ]]; then
    mv "$LOGFILE" "${LOGFILE}.1"
fi

# DNS server IPs, test domain, and expected IP passed as parameters
DNS1_IP="$1"
DNS2_IP="$2"
TEST_DOMAIN="$3"
EXPECTED_IP="$4"
RULE_ID1="$5"
RULE_ID2="$6"
RULE_ID3="$7"
RULE_ID4="$8"
SECONDS_DELAY="$9"


#sleep for seconds delay
sleep $SECONDS_DELAY

# Get the directory of the current script
SCRIPT_DIR=$(dirname "$0")


ping_test() {
    local ip=$1
    ping -c 1 -W 1 $ip >/dev/null 2>&1
    return $?
}


# Try pinging DNS1 and DNS2
ping_test $DNS1_IP
PING_DNS1_STATUS=$?

ping_test $DNS2_IP
PING_DNS2_STATUS=$?

if [ $PING_DNS1_STATUS -ne 0 ] && [ $PING_DNS2_STATUS -ne 0 ]; then
    if [ ! -e ${STATE_FILE} ]; then
        echo "$(date) - Cannot ping either DNS server. Enabling rules." >> $LOGFILE
        echo "Cannot ping either DNS server. Enabling rules."
        touch ${STATE_FILE}
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID1 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID2 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID3 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID4 enable
    else
        echo "Cannot ping either DNS server, but rules are already enabled."
        echo "$(date) - Cannot ping either DNS server, but rules are already enabled." >> $LOGFILE
    fi
    exit 1
fi



# Check DNS responses using dig
DNS1_RESPONSE=$(dig @${DNS1_IP} ${TEST_DOMAIN} +short)
DNS2_RESPONSE=$(dig @${DNS2_IP} ${TEST_DOMAIN} +short)


# Function to check DNS and set status# Function to check DNS and set status
check_dns () {
    local dns_ip=$1
    local expected_ip=$2
    local dns_response=$(dig @$dns_ip $TEST_DOMAIN +short)

    # Redirect these messages directly to the logfile
    echo "$(date) - DNS returned: ${dns_response}, expected: ${EXPECTED_IP}" >> $LOGFILE
    echo "DNS returned: ${dns_response}, expected: ${EXPECTED_IP}" >> $LOGFILE

    for ip in $dns_response; do
        if [ "$ip" == "$expected_ip" ]; then
            echo "Checking IP: ${ip}, expected: ${EXPECTED_IP}" >> $LOGFILE
            echo 0
            return
        fi
    done
    echo 1
}

# Initial DNS check
DNS1_STATUS=$(check_dns $DNS1_IP $EXPECTED_IP)
DNS2_STATUS=$(check_dns $DNS2_IP $EXPECTED_IP)


if [[ $DNS1_STATUS -ne 0 || $DNS2_STATUS -ne 0 ]]; then
    echo "$(date) - Failed checkng again in 5 seconds." >> $LOGFILE
    echo "Failed checkng again in 5 seconds."
fi

# If initial check fails, wait 5 seconds and re-check
if [ $DNS1_STATUS -ne 0 ]; then

    sleep 5
    DNS1_STATUS=$(check_dns $DNS1_IP $EXPECTED_IP)
fi

if [ $DNS2_STATUS -ne 0 ]; then

    sleep 5
    DNS2_STATUS=$(check_dns $DNS2_IP $EXPECTED_IP)
fi


# Both DNS servers are not responding or not matching expected IP
if [ ${DNS1_STATUS} -ne 0 ] && [ ${DNS2_STATUS} -ne 0 ]; then
    if [ ! -e ${STATE_FILE} ]; then
        echo "Not responding or not matching expected IP, enabling NAT rules. DNS1 returned: ${DNS1_RESPONSE}, DNS2 returned: ${DNS2_RESPONSE}"
        echo "$(date) - Not responding or not matching expected IP, enabling NAT rules" >> $LOGFILE
        echo "Not responding or not matching expected IP, enabling NAT rules"
        # Create the state file to indicate that NAT rules were enabled
        touch ${STATE_FILE}

        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID1 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID2 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID3 enable
        php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID4 enable
    else
        echo "DNS is down, but rules are already enabled."
        echo "$(date) - DNS is down, but rules are already enabled." >> $LOGFILE
    fi
    # Both or one of the DNS servers is responding or matching expected IP
    elif [ -e ${STATE_FILE} ]; then
    echo "Success, disabling NAT rules. DNS1 returned: ${DNS1_RESPONSE}, DNS2 returned: ${DNS2_RESPONSE}"
    echo "$(date) - Success, disabling NAT rules. DNS1 returned: ${DNS1_RESPONSE}, DNS2 returned: ${DNS2_RESPONSE}" >> $LOGFILE
    # Remove the state file to indicate that NAT rules can be disabled
    rm ${STATE_FILE}

    php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID1 disable
    php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID2 disable
    php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID3 disable
    php "${SCRIPT_DIR}/fwrule_toggle.php" $RULE_ID4 disable
else
    echo "DNS is up and matching expected IP, no action needed. DNS1 returned: ${DNS1_RESPONSE}, DNS2 returned: ${DNS2_RESPONSE}"
    echo "$(date) - DNS is up and matching expected IP ${EXPECTED_IP}, no action needed" >> $LOGFILE
    echo "DNS is up and matching expected IP ${EXPECTED_IP}, no action needed"
fi