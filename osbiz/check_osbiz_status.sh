#!/bin/bash

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version: 0.1
# Autor: Manuel Michalski (www.47k.de)
# Datum: 27.06.2025
# Change: 27.06.2025
# Description: Check OSBiz Status

# Test-Mode
#INPUT_FILE="/usr/lib/check_mk_agent/plugins/OSO.txt"

# Productive-Mode
INPUT_FILE=$(mktemp)
/sbin/oso_status.sh > "$INPUT_FILE" 2>/dev/null

### Variables ###
NAME="OSBIZ"
#################

active_image=$(grep "Active image" "$INPUT_FILE" | awk -F'[][]' '{print $2}')
itil_version=$(grep "ITIL version" "$INPUT_FILE" | awk -F'[][]' '{print $2}')
distribution=$(grep "Distribution" "$INPUT_FILE" | awk -F'[][]' '{print $2}')
status_osbiz=$(grep "Status of OSBiz" "$INPUT_FILE" | awk -F'[][]' '{print $2}' | xargs)

components_block=$(awk '/# Status of OSBiz components:/,/^#=/' "$INPUT_FILE" | sed '/^#=/d' | sed 's/^# //' | grep '\[')

problem_components=()
long_component_output=""
while read -r line; do
    while [[ $line =~ ([^[]+)\[([^\]]+)\] ]]; do
        compname="${BASH_REMATCH[1]}"
        compstat="$(echo "${BASH_REMATCH[2]}" | xargs)"
        line="${line#*"${BASH_REMATCH[0]}"}"
        compname_clean=$(echo "$compname" | xargs)

        long_component_output+="$compname_clean [$compstat]\n"

        if [[ "$compname_clean" == "UCSmart" ]]; then
            [[ "$compstat" != "down" ]] && problem_components+=("$compname_clean: $compstat")
        else
            [[ "$compstat" != "active" ]] && problem_components+=("$compname_clean: $compstat")
        fi
    done
done <<< "$components_block"

ENVSTATUS="Active image: $active_image\nITIL version: $itil_version\nDistribution: $distribution"
COMPONENTSTATUS="${long_component_output}\nStatus of OSBiz [$status_osbiz]"

summary="OSBiz: $status_osbiz"
if [[ ${#problem_components[@]} -gt 0 ]]; then
    summary+=" | Problem: ${problem_components[*]}"
fi

if [[ "$status_osbiz" != "active" ]]; then
    STATUS=2
    STATE="CRIT"
elif [[ ${#problem_components[@]} -ge 2 ]]; then
    STATUS=2
    STATE="CRIT"
elif [[ ${#problem_components[@]} -eq 1 ]]; then
    STATUS=1
    STATE="WARN"
else
    STATUS=0
    STATE="OK"
fi

echo "<<<local>>>"

if [[ $STATUS == 0 ]]; then
    echo "$STATUS '$NAME Status' - $STATE: $summary | Click for details \\n ${ENVSTATUS//$'\n'/\\n} \\n\\n ${COMPONENTSTATUS//$'\n'/\\n}"
else
    echo "$STATUS '$NAME Status' - $STATE: $summary | Click for details \\n ${ENVSTATUS//$'\n'/\\n} \\n\\n ${COMPONENTSTATUS//$'\n'/\\n}"
fi

exit $STATUS
