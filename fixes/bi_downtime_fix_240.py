# 1. omd su sitename
# 2. nano ~/local/lib/python3/cmk/gui/plugins/views/bi_downtime_fix_240.py
# 3. omd restart apache
#
# Author Manuel Michalski - www.47k.de / ChatGPT
# Date: 16.12.2025

# Fix BI downtime scheduling for Checkmk 2.4.x
# Handles BI rows without 'host_name' by expanding aggr_hosts
# Safe, minimal, idempotent

import logging
from cmk.gui.views.command import commands as _cmd

log = logging.getLogger(__name__)

cls = _cmd.CommandScheduleDowntimesForm

if not getattr(cls, "_bi_fix_240_applied", False):
    _orig = cls._downtime_specs

    def _patched(self, cmdtag, row, action_rows, spec):
        try:
            return _orig(self, cmdtag, row, action_rows, spec)
        except KeyError as e:
            if str(e) != "'host_name'":
                raise

            # Nur BI-Fälle anfassen
            bi_hosts = set()
            for r in action_rows or []:
                for site, host in r.get("aggr_hosts", []):
                    if site and host and not host.startswith("Max recursion"):
                        bi_hosts.add((site, host))

            if not bi_hosts:
                raise  # nichts sinnvoll ableitbar

            patched_rows = [
                {"site": site, "host_name": host}
                for site, host in bi_hosts
            ]

            log.warning(
                "BI downtime fix applied (2.4.x): expanded %d hosts",
                len(patched_rows),
            )

            return _orig(self, cmdtag, row, patched_rows, spec)

    cls._downtime_specs = _patched
    cls._bi_fix_240_applied = True
