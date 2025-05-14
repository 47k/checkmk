#!/bin/sh
# Version 0.1 - Manuel Michalski
# Website: www.47k.de
# Datum: 14.05.2025
# Description: MBUF Cluster Usage Monitor für pfSense

WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

while getopts "w:c:" opt; do
    case "$opt" in
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        *) echo "Usage: $0 [-w warning] [-c critical]"; exit 3 ;;
    esac
done

limit_items=$(sysctl -n vm.uma.mbuf_cluster.limit.items 2>/dev/null)
free_items=$(sysctl -n vm.uma.mbuf_cluster.keg.domain.0.free_items 2>/dev/null)
cluster_total=$(sysctl -n vm.uma.mbuf_cluster.limit.max_items 2>/dev/null)

if [ -z "$limit_items" ] || [ -z "$free_items" ] || [ -z "$cluster_total" ]; then
    echo "UNKNOWN - Konnte Cluster-Werte nicht auslesen | mbuf_cluster_usage=0%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100"
    exit 3
fi

cluster_used=$(echo "$limit_items + $free_items" | bc)
usage_percent=$(echo "scale=2; $cluster_used / $cluster_total * 100" | bc | awk '{printf "%d\n", $1}')

if [ "$usage_percent" -ge "$CRITICAL_THRESHOLD" ]; then
    status="CRITICAL"
elif [ "$usage_percent" -ge "$WARNING_THRESHOLD" ]; then
    status="WARNING"
else
    status="OK"
fi

echo "$status - Cluster usage at ${usage_percent}% ($cluster_used/$cluster_total) | mbuf_cluster_usage=${usage_percent}%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100"
