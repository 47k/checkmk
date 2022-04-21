#!/bin/tcsh

#Version 0.1 - Manuel Michalski
#Website: www.47k.de
#Last Update: 30.03.2022
#Description: pfSense CARP Status Check

### Set Main Mode #########
set should=Master
set hostname=pfsense-am-p1

#set should=Backup
#set hostname=pfsense-am-p2
###########################

ifconfig |grep -q 'MASTER'
set ismaster=$status

ifconfig |grep -q 'BACKUP'
set isbackup=$status

# Status = 141 (Mehrere Einträge)
# Status = 0 (Ein Eintrag gefunden)
# Status = 1 (Kein Eintrag gefunden)

if ($ismaster == 1 && $isbackup == 1) then
        echo "Ok - No Carp detected"
	exit 0
        exit
endif

# Prüfen ob Master & Backup gefunden wurden
if (($ismaster == 141 || $ismaster == 0) && ($isbackup == 141 || $isbackup == 0)) then
        echo "Wrong configuration"
        exit
endif

if ($ismaster == 141 || $ismaster == 0 )then
        set STATUS=Master
endif

if ($isbackup == 141 || $isbackup == 0) then
        set STATUS=Backup
endif

if ($should == $STATUS) then
        echo "OK - $hostname is running as MASTER"
        exit 0
        else
        echo "CRITICAL - $hostname is running as $STATUS but should be $should"
        exit 2
endif
