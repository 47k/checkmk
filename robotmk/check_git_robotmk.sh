#!/bin/bash
#Version 0.2 - Manuel Michalski
#Website: www.47k.de
#Description: Check Version Local <-> GIT - Checkmk-Agent-Plugin-RobotMK

### Variables ###
LOCALFILE=/opt/omd/sites/sitename/var/check_mk/packages/robotmk
REPONAME=simonmeggle/robotmk
WEBSITE=https://github.com/simonmeggle/robotmk/
NAME=RobotMK
TOKEN=
################

LOCAL=$(cat $LOCALFILE |grep "'version':" | sed -E "s/.*'([^']+)'.*/\1/")
ONLINE=$(curl --silent -u $TOKEN "https://api.github.com/repos/$REPONAME/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ $LOCAL = $ONLINE ]; then
	UPDATE=0
	else UPDATE=1
fi

if [ $UPDATE = 0 ]; then
        echo "<<<local>>>"
	echo "0 'Update $NAME Plugin' Status=$UPDATE OK: Keine neuen Plugin Updates | Installierte Version: $LOCAL"
        	else
		echo "<<<local>>>"
        	echo "1 'Update $NAME Plugin' Status=$UPDATE WARN: Neues $NAME Plugin Update - Check $WEBSITE | Installierte Version: $LOCAL | Verfügbare Version: $ONLINE"
fi
