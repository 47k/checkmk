#!/bin/sh
# Version 0.3 - Manuel Michalski
# Website: www.47k.de
# Datum: 07.08.2024
# Description: CheckMK - Check pfSense PPPoE Status und Uptime

# PPPoE-Interface-Name
INTERFACE="pppoe0"

# Pfad zum Uptime-Script
UPTIME_SCRIPT="/usr/local/sbin/ppp-uptime.sh"

check_pppoe_status_and_uptime() {
    # Prüfe den PPPoE-Verbindungsstatus
    pppoe_status=$(ifconfig $INTERFACE | grep -o "RUNNING")
    connection_status=0

    if [ "$pppoe_status" = "RUNNING" ]; then
        connection_status=1
        status_message="OK - PPPoE connection is active"
    else
        status_message="CRITICAL - PPPoE connection is down"
        echo "$status_message | connection_status=$connection_status;;;0;1 uptime=0s;;28800;10800;"
        exit 2
    fi

    # Prüfe die PPPoE-Uptime
    if [ -x "$UPTIME_SCRIPT" ]; then
        uptime=$(sh $UPTIME_SCRIPT $INTERFACE)

        if [ $? -ne 0 ]; then
            echo "UNKNOWN - Unable to retrieve PPPoE uptime | connection_status=$connection_status;;;0;1 uptime=0s;;28800;10800;"
            exit 3
        fi

        # Berechne die Uptime in Tagen und Stunden
        uptime_days=$((uptime / 86400))
        uptime_hours=$(( (uptime % 86400) / 3600 ))

        # Setze Status basierend auf der Uptime
        if [ $uptime -lt 10800 ]; then  # weniger als 3 Stunden in Sekunden
            status_message="CRITICAL - PPPoE Uptime is less than 3 hours"
            exit_status=2
        elif [ $uptime -lt 28800 ]; then  # weniger als 8 Stunden in Sekunden
            status_message="WARNING - PPPoE Uptime is less than 8 hours"
            exit_status=1
        else
            status_message="OK - PPPoE Uptime is ${uptime_days}d ${uptime_hours}h"
            exit_status=0
        fi

        # Ausgabe der finalen Statusmeldung und der Performance-Daten
        echo "$status_message | connection_status=$connection_status;;;0;1 uptime=${uptime}s;;28800;10800;"
        exit $exit_status
    else
        echo "UNKNOWN - Uptime script not found or not executable | connection_status=$connection_status;;;0;1 uptime=0s;;28800;10800;"
        exit 3
    fi
}

main() {
    check_pppoe_status_and_uptime
}

main
