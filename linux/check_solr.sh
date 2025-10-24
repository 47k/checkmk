#!/bin/bash

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version 0.3 - Manuel Michalski
# Date: 21.07.2022
# Change: 14.10.2025
# Description: CheckMK - Check SOLR Version

### Variables ###
YEAR=$(date +%Y)
WEBSITE=https://github.com/apache/solr
################

LOCAL=$(/opt/solr/bin/solr -v | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

ONLINE=$(curl -s -H 'Accept: application/vnd.github+json' 'https://api.github.com/repos/apache/solr/tags?per_page=100' \
| jq -r '.[].name' \
| grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' \
| sort -V \
| tail -n1)

if [ "$LOCAL" = "$ONLINE" ]; then
    UPDATE=0
    else UPDATE=1
fi

if [ $UPDATE = 0 ]; then
        echo "<<<local>>>"
    echo "0 'Solr' Status=$UPDATE OK: Kein neues Solr Update | Installierte Version: $LOCAL"
else
        echo "<<<local>>>"
        echo "1 'Solr' Status=$UPDATE WARN: Neues Solr Update - Check $WEBSITE | Installierte Version: $LOCAL | Verfügbare Version: $ONLINE"
fi
