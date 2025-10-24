# ~/local/lib/python3/cmk/gui/plugins/views/zz_bi_site_fix.py
# -----------------------------------------------------------------------------
# Checkmk 2.3.0p39 – BI Renderer Site Fix
#
# This patch addresses a persistent KeyError in the BI view caused by missing
# or invalid `row["site"]` entries during tree rendering in
# `foldable_tree_renderer.FoldableTreeRendererTree._show_node`.
#
# The fix implements:
#   1. A tolerant wrapper for `active_config.sites` to avoid KeyErrors.
#   2. Automatic assignment of a valid `row["site"]` before rendering.
#   3. Reinjection of a valid `row["site"]` right before the original
#      `_show_node` context manager exits (where the crash occurs).
#
# Placing this file in `plugins/views/` and prefixing it with `zz_` ensures
# it loads *after* the official BI modules, overriding their behavior safely.
#
# 1. omd su sitename
# 2. nano ~/local/lib/python3/cmk/gui/plugins/views/zz_bi_site_fix.py
# 3. omd restart apache
#
# Author Manuel Michalski - www.47k.de / ChatGPT
# Date: 23.09.2025 
#
# -----------------------------------------------------------------------------

from contextlib import contextmanager
from collections.abc import MutableMapping
from cmk.gui import config as active_config
from cmk.gui.bi import foldable_tree_renderer as ftr

# --- 1) Wrap active_config.sites to avoid KeyErrors ---
class _SitesWrapper(MutableMapping):
    __slots__ = ("_base",)
    def __init__(self, base):
        self._base = dict(base) if base is not None else {}
    def __getitem__(self, key):
        return self._base.get(key, {})          # Avoid KeyError
    def __setitem__(self, key, value):
        self._base[key] = value
    def __delitem__(self, key):
        del self._base[key]
    def __iter__(self):
        return iter(self._base)
    def __len__(self):
        return len(self._base)
    def get(self, key, default=None):
        if default is None:
            default = {}
        return self._base.get(key, default)

if not isinstance(getattr(active_config, "sites", {}), _SitesWrapper):
    active_config.sites = _SitesWrapper(getattr(active_config, "sites", {}))

# --- 2) Helper functions to ensure valid row["site"] ---
def _first_configured_site():
    for k in active_config.sites:
        return k
    return "local"

def _derive_site_from_row(row: dict):
    hosts = row.get("reqhosts") or row.get("aggr_hosts") or []
    for h in hosts:
        if isinstance(h, (list, tuple)) and len(h) == 2 and h[0]:
            return h[0]
    return None

def _ensure_row_site(row: dict):
    if not isinstance(row, dict):
        return
    site = row.get("site") or _derive_site_from_row(row) or _first_configured_site()
    if not isinstance(active_config.sites[site], dict):
        site = _first_configured_site()
    row["site"] = site

# --- 3) Patch renderer methods ---
# 3a) render() – ensure site early
if not getattr(ftr.FoldableTreeRendererTree, "_bi_fix_render_applied", False):
    _orig_render = ftr.FoldableTreeRendererTree.render
    def _patched_render(self):
        _ensure_row_site(getattr(self, "_row", None))
        return _orig_render(self)
    ftr.FoldableTreeRendererTree.render = _patched_render
    ftr.FoldableTreeRendererTree._bi_fix_render_applied = True

# 3b) _show_node() – ensure site before __exit__
if not getattr(ftr.FoldableTreeRendererTree, "_bi_fix_shownode_applied", False):
    _orig_shownode = ftr.FoldableTreeRendererTree._show_node

    @contextmanager
    def _patched_shownode(self, tree, show_host, mousecode=None, img_class=None):
        cm = _orig_shownode(self, tree, show_host, mousecode, img_class)
        cm.__enter__()
        try:
            yield
        except BaseException as exc:
            _ensure_row_site(getattr(self, "_row", None))
            if not cm.__exit__(type(exc), exc, exc.__traceback__):
                raise
        else:
            _ensure_row_site(getattr(self, "_row", None))
            cm.__exit__(None, None, None)

    ftr.FoldableTreeRendererTree._show_node = _patched_shownode
    ftr.FoldableTreeRendererTree._bi_fix_shownode_applied = True
