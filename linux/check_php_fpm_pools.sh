#!/usr/bin/env bash

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version: 1.3 - Manuel Michalski
# Date: 05.05.2023
# Change: 20.10.2025 
# Description: Check PHP FPM Pools to be up-to-date. Compare configuration in /etc/check_mk/php_fpm_pools.cfg with running processes

set -u
export LC_ALL=C

### Variables ###
CHECKMKPOOLFILE="/etc/check_mk/php_fpm_pools.cfg"
POOLSRUNNING_DIR="/var/run/php"
ALT_POOLS_DIR="/run/php"
MINPROCS=1
MAXCHARS=25
COUNT=0
#################

echo "<<<local>>>"

# Fallback auf /run/php
if [ ! -d "$POOLSRUNNING_DIR" ] && [ -d "$ALT_POOLS_DIR" ]; then
  POOLSRUNNING_DIR="$ALT_POOLS_DIR"
fi

if [ ! -f "$CHECKMKPOOLFILE" ]; then
  echo "3 'PHP-FPM Pool Sync' | Running_Pools=0 CRIT: CheckMK Pool file doesn't exist ($CHECKMKPOOLFILE)"
  exit 0
fi

# Konfigurierte Sockets -> Poolnamen
CHKMK_SHORT=""
while IFS= read -r line; do
  if [[ $line =~ /(var/run|run)/php/(.*)\.sock ]]; then
    CHKMK_SHORT+="${BASH_REMATCH[2]}"$'\n'
  fi
done < <(grep -F "sock" "$CHECKMKPOOLFILE" | sort)

# Laufende Sockets -> Poolnamen
RUN_SHORT=""
if [ -d "$POOLSRUNNING_DIR" ]; then
  while IFS= read -r fname; do
    [[ -z "$fname" ]] && continue
    if [[ $fname =~ (.*)\.sock$ ]]; then
      RUN_SHORT+="${BASH_REMATCH[1]}"$'\n'
      ((COUNT++))
    fi
  done < <(ls -1 "$POOLSRUNNING_DIR" 2>/dev/null | grep -F "sock" | sort)
fi

# Long-Output mit literal \n zusammenbauen (erste Zeile mit führendem Space)
LONGMSG=""
first=1
while IFS= read -r r; do
  [[ -z "$r" ]] && continue
  if (( first )); then
    LONGMSG+="\\n $r - running"
    first=0
  else
    LONGMSG+="\\n$r - running"
  fi
done < <(printf "%s" "$RUN_SHORT")

# Mindestens X Pools?
if (( COUNT < MINPROCS )); then
  echo "3 'PHP-FPM Pool Sync' | Running_Pools=$COUNT CRIT: no FPM-Pool process is running$LONGMSG"
  exit 0
fi

# Mengenvergleich
sorted_cfg=$(printf "%s" "$CHKMK_SHORT" | sed '/^$/d' | sort -u)
sorted_run=$(printf "%s" "$RUN_SHORT"   | sed '/^$/d' | sort -u)

only_run=$(comm -13 <(printf "%s" "$sorted_cfg") <(printf "%s" "$sorted_run"))
only_cfg=$(comm -23 <(printf "%s" "$sorted_cfg") <(printf "%s" "$sorted_run"))

format_names() {
  local name out=""
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    [[ $name =~ ^php-fpm-(.*)$ ]] && name="»${BASH_REMATCH[1]}«" || name="»$name«"
    out+="$name "
  done
  printf "%s" "$out"
}

ASYNC=0
MSG=""
DETAILS=""

if [[ -n "$only_run" ]]; then
  ASYNC=1
  names=$(printf "%s" "$only_run" | format_names)
  DETAILS+="\\nError - $names - not in CheckMK Pool File\\n"
  short="$names not in CheckMK Pool File"
  (( ${#short} > MAXCHARS )) && short="${short:0:$((MAXCHARS-3))}..."
  MSG+="$short "
fi

if [[ -n "$only_cfg" ]]; then
  ASYNC=1
  names=$(printf "%s" "$only_cfg" | format_names)
  DETAILS+="\\n$names - configured in CheckMK Pool File but not running\\n"
  short="$names configured in CheckMK Pool File but not running"
  (( ${#short} > MAXCHARS )) && short="${short:0:$((MAXCHARS-3))}..."
  MSG+="$short "
fi

if (( ASYNC == 0 )); then
  echo "0 'PHP-FPM Pool Sync' Running_Pools=$COUNT OK: $COUNT running PHP-FPM Pools. Config is in sync (CheckMK Pool file and Running Pools)$LONGMSG"
else
  echo "1 'PHP-FPM Pool Sync' Running_Pools=$COUNT WARN: $COUNT running PHP-FPM Pools. There is a difference between the CheckMK Pool file and the running pools $MSG$DETAILS$LONGMSG"
fi
