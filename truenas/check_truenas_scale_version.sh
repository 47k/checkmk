#!/bin/bash

# Version 0.1 - Manuel Michalski
# 47k - www.47k.de
# Date: 15. September 2023
# Description: Check TrueNAS Version (Scale)

### Variables ###
UPCHECK=$(midclt call update.check_available)
STATUS=$(echo "$UPCHECK" | jq -r '.status')
DEBUG=NO
################

# Run with sudo if we're not root
if (( EUID ))
then
    SUDO='/usr/local/bin/sudo'
fi

# Run the command and:
#  - Dump all output
#  - check the exit status:
#     0 = updates available
#     1 = no updates

echo "<<<local>>>"

if [ "$STATUS" == "AVAILABLE" ]; then
    VERSION=$(echo "$UPCHECK" | jq -r '.changes[0].old.version')
    VERSIONNEW=$(echo "$UPCHECK" | jq -r '.changes[0].new.version')
    echo "1 'TrueNAS Version' WARN: Update $STATUS | Installed Version: $VERSION Available Version: $VERSIONNEW"
    exit 1
else
    echo "0 'TrueNAS Version' OK: No updates available"
    exit 0
fi

if [ $DEBUG = YES ]; then
    	echo
    	echo ---- Debug ----
	    echo Upcheck: $UPCHECK
    	echo Status: $STATUS
    	echo Version: $VERSION
    	echo Versionnew: $VERSIONNEW
    	echo ---- End ----
    	echo
fi
