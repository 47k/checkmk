#!/bin/bash
#Version 0.2 - Manuel Michalski
#Website: www.47k.de
#Description: Check Version Local <-> GIT - OCS-Inventory

### Variables ###
LOCALFILE=/usr/share/ocsinventory-reports/ocsreports/var.php
REPONAME=OCSInventory-NG/OCSInventory-ocsreports
WEBSITE=https://github.com/OCSInventory-NG/OCSInventory-ocsreports
NAME='OCS-Inventory Server'
TOKEN=
################

LOCAL=$(cat $LOCALFILE |grep "GUI_VER_SHOW" | sed -E "s/.*'([^']+)'.*/\1/")
ONLINE=$(curl --silent -u $TOKEN "https://api.github.com/repos/$REPONAME/releases/latest" | grep '"tag_name":' | sed -ne 's/.*"tag_name": "[a-zA-Z_]*\([0-9._]\+\)".*/\1/p' | sed -e 's/_/./g')

if [ $LOCAL = $ONLINE ]; then
        UPDATE=0
        else UPDATE=1
fi

if [ $UPDATE = 0 ]; then
	echo "<<<local>>>"
        echo "0 '$NAME' Status=$UPDATE OK: Keine neuen Updates | Installierte Version: $LOCAL"
                else
		echo "<<<local>>>"
                echo "1 '$NAME' Status=$UPDATE WARN: Neues $NAME Update - Check $WEBSITE | Installierte Version: $LOCAL | VerfÃ¼gbare Version: $ONLINE"
fi
