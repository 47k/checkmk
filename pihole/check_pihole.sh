#!/bin/sh

#Version 0.3 - Manuel Michalski <47k.de>
#Datum: 15.04.2023
#Description: Check Pihole Update

### Variables ###
pihole_status="$(/usr/local/bin/pihole status)"
pihole_error="$(echo "$pihole_status" | grep 'DNS service is NOT running')"
pihole_ok="$(echo "$pihole_status" | xargs | grep -E 'FTL is listening.*Pi-hole blocking is enabled')"

pihole_version="$(/usr/local/bin/pihole -v)"
pihole_installed_version="$(echo "$pihole_version" | awk {'print $4'})"
pihole_last_version="$(echo "$pihole_version" | awk {'print $6'} | sed 's/)//')"
################

if [ ! -z "$pihole_error" ]; then
        echo "2 Pi-Hole - CRIT: Pi-Hole service is NOT running"
elif [ ! -z "$pihole_ok" ]; then
        if [ "$pihole_installed_version" != "$pihole_last_version" ]; then
                echo "1 Pi-Hole - WARN: Pi-Hole updates are available"
        else
                echo "0 Pi-Hole - OK: Pi-Hole service is running | No Updates"
        fi
else
        echo "1 Pi-Hole - WARN: Pi-Hole is partially working, probably not blocking Ads"
fi
