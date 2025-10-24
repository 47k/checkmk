# ~/local/share/check_mk/web/plugins/views/bi_downtime_fix.py
#
# 1. omd su sitename
# 2. nano ~/local/lib/python3/cmk/gui/plugins/views/bi_downtime_fix.py
# 3. omd restart apache
#
# Author Manuel Michalski - www.47k.de
# Date: 23.09.2025

import logging
from cmk.gui.views.command import commands as _cmd

log = logging.getLogger(__name__)

# Idempotenz: nur patchen, wenn noch nicht gepatcht
if not getattr(_cmd.CommandScheduleDowntimes, "_bi_fix_applied", False):
    _orig = _cmd.CommandScheduleDowntimes._downtime_specs

    def _patched(self, cmdtag, row, action_rows, spec):
        try:
            return _orig(self, cmdtag, row, action_rows, spec)
        except KeyError as e:
            # Nur unseren bekannten Fall anfassen
            if str(e) != "'host_name'":
                raise

            # Nur, wenn es BI-Rows sind (aggr_hosts vorhanden)
            has_bi = any("aggr_hosts" in (r or {}) for r in (action_rows or []))
            if not has_bi:
                # Kein BI-Context -> originaler Fehler
                raise

            # Aus BI-Zeilen aggr_hosts -> (site, host) ableiten
            hosts = set()
            for r in action_rows or []:
                for site, host in r.get("aggr_hosts", []):
                    if host:
                        hosts.add((site, host))

            if not hosts:
                # Nichts ableitbar -> originaler Fehler
                raise

            patched_rows = [{"site": s, "host_name": h} for (s, h) in hosts]
            return _orig(self, cmdtag, row, patched_rows, spec)

    _cmd.CommandScheduleDowntimes._downtime_specs = _patched
    _cmd.CommandScheduleDowntimes._bi_fix_applied = True
    log.warning("bi_downtime_fix loaded: BI downtime host expansion active")
