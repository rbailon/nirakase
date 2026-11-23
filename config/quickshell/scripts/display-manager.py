#!/usr/bin/env python3
"""Nirakase Display Manager backend for Niri + Quickshell.

Handles:
- Querying live Niri outputs, focused output, wl-mirror state, and saved profiles
- Per-topology multi-monitor profile persistence (~/.local/state/nirakase/displays.json)
- Managed Niri KDL output generation (~/.local/state/nirakase/outputs.kdl)
- Atomic / two-phase non-overlapping output reconfiguration with focus preservation
- Automatic profile restoration on session startup and monitor hotplug/unplug
"""

import argparse
import fcntl
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager, suppress
from pathlib import Path

ALLOWED_TRANSFORMS = {
    "normal",
    "90",
    "180",
    "270",
    "flipped",
    "flipped-90",
    "flipped-180",
    "flipped-270",
}

MODE_RE = re.compile(r"^(\d+)x(\d+)(?:@(\d+(?:\.\d+)?))?$")
INTERNAL_PREFIXES = ("eDP-", "LVDS-", "DSI-")


def handle_sig(_sig, _frame):
    sys.exit(0)


signal.signal(signal.SIGINT, handle_sig)
signal.signal(signal.SIGTERM, handle_sig)


def state_dir() -> Path:
    xdg_state = os.environ.get("XDG_STATE_HOME", "").strip()
    base = Path(xdg_state) if xdg_state else (Path.home() / ".local" / "state")
    target = base / "nirakase"
    target.mkdir(parents=True, exist_ok=True)
    return target


def profiles_path() -> Path:
    return state_dir() / "displays.json"


def outputs_kdl_path() -> Path:
    return state_dir() / "outputs.kdl"


def lock_path() -> Path:
    return state_dir() / ".display-manager.lock"


@contextmanager
def state_lock():
    lp = lock_path()
    fd = os.open(str(lp), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        with suppress(OSError):
            fcntl.flock(fd, fcntl.LOCK_UN)
        with suppress(OSError):
            os.close(fd)


def atomic_write_text(path: Path, text: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    old_umask = os.umask(0o077)
    tmp_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(path.parent),
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as fh:
            tmp_name = fh.name
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, path)
    except Exception:
        if tmp_name:
            with suppress(OSError):
                os.unlink(tmp_name)
        raise
    finally:
        os.umask(old_umask)


def is_internal_connector(name: str) -> bool:
    return bool(name) and name.startswith(INTERNAL_PREFIXES)


def normalize_transform(raw) -> str:
    if not raw:
        return "normal"
    s = str(raw).strip().lower().lstrip("_")
    mapping = {
        "normal": "normal",
        "90": "90",
        "180": "180",
        "270": "270",
        "flipped": "flipped",
        "flipped90": "flipped-90",
        "flipped-90": "flipped-90",
        "flipped180": "flipped-180",
        "flipped-180": "flipped-180",
        "flipped270": "flipped-270",
        "flipped-270": "flipped-270",
    }
    return mapping.get(s, "normal")


def is_rotated(transform: str) -> bool:
    return normalize_transform(transform) in ("90", "270", "flipped-90", "flipped-270")


def format_scale(scale: float) -> str:
    val = max(0.25, min(4.0, round(float(scale), 4)))
    if abs(val - round(val)) < 1e-4:
        return str(round(val))
    return f"{val:.4f}".rstrip("0").rstrip(".")


def compute_logical_size(phys_w: int, phys_h: int, scale: float, transform: str) -> tuple[int, int]:
    sc = max(0.25, float(scale) if scale else 1.0)
    if is_rotated(transform):
        return max(1, round(phys_h / sc)), max(1, round(phys_w / sc))
    return max(1, round(phys_w / sc)), max(1, round(phys_h / sc))


def parse_mode_cmd(mode_cmd: str) -> tuple[int, int, float | None] | None:
    if not mode_cmd:
        return None
    m = MODE_RE.match(str(mode_cmd).strip())
    if not m:
        return None
    w = int(m.group(1))
    h = int(m.group(2))
    hz = float(m.group(3)) if m.group(3) else None
    return w, h, hz


def run_niri_json(*args: str):
    proc = subprocess.run(
        ["niri", "msg", "-j", *args],
        check=False,
        capture_output=True,
        text=True,
        shell=False,
        timeout=5,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"niri msg -j {' '.join(args)} failed")
    out = proc.stdout.strip()
    if not out:
        return None
    return json.loads(out)


def niri_output(*args: str) -> bool:
    proc = subprocess.run(
        ["niri", "msg", "output", *args],
        check=False,
        capture_output=True,
        text=True,
        shell=False,
        timeout=5,
    )
    return proc.returncode == 0


def niri_action(*args: str) -> bool:
    proc = subprocess.run(
        ["niri", "msg", "action", *args],
        check=False,
        capture_output=True,
        text=True,
        shell=False,
        timeout=5,
    )
    return proc.returncode == 0


def get_focused_output_name() -> str:
    with suppress(OSError, RuntimeError, ValueError, subprocess.SubprocessError):
        data = run_niri_json("focused-output")
        if isinstance(data, dict) and data.get("name"):
            return str(data["name"])
    return ""


def get_wl_mirror_state() -> dict:
    installed = shutil.which("wl-mirror") is not None
    active = False
    source = ""
    target = ""
    with suppress(OSError, subprocess.SubprocessError):
        proc = subprocess.run(
            ["ps", "-C", "wl-mirror", "-o", "args="],
            check=False,
            capture_output=True,
            text=True,
            shell=False,
            timeout=3,
        )
        lines = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
        if lines:
            parts = lines[0].split()
            active = True
            idx = 0
            while idx < len(parts):
                token = parts[idx]
                if token in ("--fullscreen-output", "-F") and idx + 1 < len(parts):
                    target = parts[idx + 1]
                    idx += 2
                    continue
                if not token.startswith("-") and "wl-mirror" not in os.path.basename(token):
                    source = token
                idx += 1
    return {
        "installed": installed,
        "active": active,
        "source": source,
        "target": target,
    }


def stop_wl_mirror() -> None:
    with suppress(OSError, subprocess.SubprocessError):
        subprocess.run(
            ["pkill", "-x", "wl-mirror"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            shell=False,
            timeout=3,
        )


def start_wl_mirror(source: str, target: str) -> bool:
    if not source or not target or shutil.which("wl-mirror") is None:
        return False
    try:
        subprocess.Popen(
            ["wl-mirror", "--fullscreen-output", target, source],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
            shell=False,
        )
        return True
    except (OSError, subprocess.SubprocessError):
        return False


def sync_wallpaper() -> None:
    if shutil.which("nirakase-wallpaper") is None:
        return
    with suppress(OSError, subprocess.SubprocessError):
        subprocess.Popen(
            ["nirakase-wallpaper", "--sync-current"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
            shell=False,
        )


def load_store() -> dict:
    path = profiles_path()
    if not path.is_file():
        return {"version": 1, "profiles": {}, "output_defaults": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise TypeError("invalid store root")
        data.setdefault("version", 1)
        data.setdefault("profiles", {})
        data.setdefault("output_defaults", {})
        return data
    except (OSError, ValueError, TypeError):
        return {"version": 1, "profiles": {}, "output_defaults": {}}


def save_store(store: dict) -> None:
    atomic_write_text(profiles_path(), json.dumps(store, indent=2, sort_keys=True) + "\n")


def compute_fingerprints(raw_outputs: dict) -> dict[str, str]:
    """Compute stable per-output hardware fingerprints, disambiguating identical models."""
    base_fps: dict[str, str] = {}
    counts: dict[str, int] = {}
    for name in sorted(raw_outputs.keys()):
        o = raw_outputs.get(name) or {}
        make = str(o.get("make") or "").strip()
        model = str(o.get("model") or "").strip()
        serial = str(o.get("serial") or "").strip()
        if make or model or serial:
            fp = f"{make}|{model}|{serial}"
        else:
            fp = f"connector:{name}"
        base_fps[name] = fp
        counts[fp] = counts.get(fp, 0) + 1

    resolved: dict[str, str] = {}
    for name, fp in base_fps.items():
        if counts.get(fp, 0) > 1:
            resolved[name] = f"{fp}@{name}"
        else:
            resolved[name] = fp
    return resolved


def topology_keys(raw_outputs: dict, fps: dict[str, str]) -> tuple[str, str]:
    topo_key = "::".join(sorted(fps.values()))
    conn_key = ",".join(sorted(raw_outputs.keys()))
    return topo_key, conn_key


def structure_outputs(raw_outputs: dict, fps: dict[str, str], store: dict) -> list[dict]:
    keys = sorted(
        raw_outputs.keys(),
        key=lambda k: (0 if is_internal_connector(k) else 1, k),
    )
    output_defaults = store.get("output_defaults") or {}
    result = []

    for name in keys:
        o = raw_outputs.get(name)
        if not isinstance(o, dict):
            continue
        fp = fps[name]
        logical = o.get("logical")
        enabled = logical is not None
        modes = o.get("modes") if isinstance(o.get("modes"), list) else []
        cur_idx = o.get("current_mode")
        cur_idx = int(cur_idx) if isinstance(cur_idx, int) else -1

        active_mode = modes[cur_idx] if 0 <= cur_idx < len(modes) else None
        if active_mode is None and modes:
            for md in modes:
                if md.get("is_preferred"):
                    active_mode = md
                    break
            if active_mode is None:
                active_mode = modes[0]

        phys_w = int(active_mode.get("width", 1920)) if active_mode else 1920
        phys_h = int(active_mode.get("height", 1080)) if active_mode else 1080
        refresh_mhz = int(active_mode.get("refresh_rate", 60000)) if active_mode else 60000
        refresh_hz_str = f"{refresh_mhz / 1000.0:.3f}"
        refresh_short = f"{round(refresh_mhz / 1000.0)}Hz"

        saved_def = output_defaults.get(fp) or {}
        if logical and logical.get("scale"):
            scale = float(logical["scale"])
        elif saved_def.get("scale"):
            scale = float(saved_def["scale"])
        else:
            scale = 1.0

        if logical and logical.get("transform"):
            transform = normalize_transform(logical["transform"])
        elif saved_def.get("transform"):
            transform = normalize_transform(saved_def["transform"])
        else:
            transform = "normal"

        if logical:
            log_w = int(logical.get("width", 1920))
            log_h = int(logical.get("height", 1080))
            log_x = int(logical.get("x", 0))
            log_y = int(logical.get("y", 0))
        else:
            log_w, log_h = compute_logical_size(phys_w, phys_h, scale, transform)
            log_x, log_y = 0, 0

        # Deduplicate modes keeping highest refresh rate per resolution+rounded Hz, up to 12 modes
        formatted_modes = []
        seen_sig = set()
        for mi, md in enumerate(modes):
            mw = int(md.get("width", 0))
            mh = int(md.get("height", 0))
            m_mhz = int(md.get("refresh_rate", 60000))
            if mw <= 0 or mh <= 0:
                continue
            hz_str = f"{m_mhz / 1000.0:.3f}"
            hz_round = round(m_mhz / 1000.0)
            sig = f"{mw}x{mh}@{hz_round}"
            is_curr = mi == cur_idx
            if sig in seen_sig and not is_curr:
                continue
            seen_sig.add(sig)
            formatted_modes.append(
                {
                    "cmd": f"{mw}x{mh}@{hz_str}",
                    "label": f"{mw}×{mh} @ {hz_round}Hz",
                    "width": mw,
                    "height": mh,
                    "refreshMhz": m_mhz,
                    "refreshHz": hz_round,
                    "isCurrent": is_curr,
                    "isPreferred": bool(md.get("is_preferred")),
                }
            )
            if len(formatted_modes) >= 12:
                break

        make_model = " ".join(p for p in (str(o.get("make") or "").strip(), str(o.get("model") or "").strip()) if p)
        if not make_model:
            make_model = "Built-in Display" if is_internal_connector(name) else "External Monitor"

        result.append(
            {
                "name": name,
                "fingerprint": fp,
                "makeModel": make_model,
                "isInternal": is_internal_connector(name),
                "enabled": enabled,
                "width": log_w,
                "height": log_h,
                "physicalWidth": phys_w,
                "physicalHeight": phys_h,
                "x": log_x,
                "y": log_y,
                "scale": scale,
                "transform": transform,
                "refreshRate": refresh_short,
                "refreshMhz": refresh_mhz,
                "modeCmd": f"{phys_w}x{phys_h}@{refresh_hz_str}",
                "modes": formatted_modes,
            }
        )
    return result


# ── Geometry helpers (overlap prevention, adjacency, normalization) ──────────


def rects_overlap(a: dict, b: dict) -> bool:
    return (
        a["x"] < b["x"] + b["width"]
        and a["x"] + a["width"] > b["x"]
        and a["y"] < b["y"] + b["height"]
        and a["y"] + a["height"] > b["y"]
    )


def rects_touch(a: dict, b: dict, min_shared: int = 1) -> bool:
    horiz_touch = (a["x"] + a["width"] == b["x"]) or (b["x"] + b["width"] == a["x"])
    vert_overlap = min(a["y"] + a["height"], b["y"] + b["height"]) - max(a["y"], b["y"])
    if horiz_touch and vert_overlap >= min_shared:
        return True
    vert_touch = (a["y"] + a["height"] == b["y"]) or (b["y"] + b["height"] == a["y"])
    horiz_overlap = min(a["x"] + a["width"], b["x"] + b["width"]) - max(a["x"], b["x"])
    return bool(vert_touch and horiz_overlap >= min_shared)


def clamp(val: int, lo: int, hi: int) -> int:
    if lo > hi:
        return (lo + hi) // 2
    return max(lo, min(hi, val))


def snap_rect_adjacent(target: dict, placed: list[dict]) -> tuple[int, int]:
    """Find the closest non-overlapping position adjacent to at least one placed rect."""
    tx, ty, tw, th = int(target["x"]), int(target["y"]), int(target["width"]), int(target["height"])
    best_pos = None
    best_dist_sq = float("inf")

    for anchor in placed:
        ax, ay, aw, ah = int(anchor["x"]), int(anchor["y"]), int(anchor["width"]), int(anchor["height"])
        min_ov_y = min(80, th, ah)
        min_ov_x = min(80, tw, aw)
        candidates = [
            # Right of anchor
            (ax + aw, clamp(ty, ay - th + min_ov_y, ay + ah - min_ov_y)),
            # Left of anchor
            (ax - tw, clamp(ty, ay - th + min_ov_y, ay + ah - min_ov_y)),
            # Below anchor
            (clamp(tx, ax - tw + min_ov_x, ax + aw - min_ov_x), ay + ah),
            # Above anchor
            (clamp(tx, ax - tw + min_ov_x, ax + aw - min_ov_x), ay - th),
        ]
        for cx, cy in candidates:
            probe = {"x": cx, "y": cy, "width": tw, "height": th}
            if any(rects_overlap(probe, p) for p in placed):
                continue
            dist_sq = (cx - tx) ** 2 + (cy - ty) ** 2
            if dist_sq < best_dist_sq:
                best_dist_sq = dist_sq
                best_pos = (cx, cy)

    if best_pos is not None:
        return best_pos

    # Fallback: place to the right of the rightmost placed rect
    max_right = max(p["x"] + p["width"] for p in placed)
    min_y = min(p["y"] for p in placed)
    return max_right, min_y


def sanitize_layout_positions(items: list[dict], primary_name: str = "") -> list[dict]:
    """Ensure enabled outputs are integer-aligned, non-overlapping, connected, and normalized to (0, 0)."""
    enabled = [dict(o) for o in items if o.get("enabled")]
    if not enabled:
        return items

    for o in enabled:
        o["x"] = round(float(o.get("x", 0)))
        o["y"] = round(float(o.get("y", 0)))
        o["width"] = max(1, round(float(o.get("width", 1920))))
        o["height"] = max(1, round(float(o.get("height", 1080))))

    # Check if already completely valid (no overlaps and single connected component)
    def is_valid_graph(rects: list[dict]) -> bool:
        n = len(rects)
        if n <= 1:
            return True
        for i in range(n):
            for j in range(i + 1, n):
                if rects_overlap(rects[i], rects[j]):
                    return False
        visited = {0}
        queue = [0]
        while queue:
            cur = queue.pop(0)
            for nxt in range(n):
                if nxt not in visited and rects_touch(rects[cur], rects[nxt], min_shared=1):
                    visited.add(nxt)
                    queue.append(nxt)
        return len(visited) == n

    if not is_valid_graph(enabled):
        # Place primary first, then snap remaining outputs closest to their requested positions
        enabled.sort(key=lambda o: (0 if o["name"] == primary_name else 1, o["x"], o["y"], o["name"]))
        placed = [enabled[0]]
        for o in enabled[1:]:
            nx, ny = snap_rect_adjacent(o, placed)
            o["x"], o["y"] = nx, ny
            placed.append(o)

    # Normalize bounding box to (0, 0)
    min_x = min(o["x"] for o in enabled)
    min_y = min(o["y"] for o in enabled)
    by_name = {}
    for o in enabled:
        o["x"] -= min_x
        o["y"] -= min_y
        by_name[o["name"]] = o

    out_list = []
    for item in items:
        copy = dict(item)
        if copy["name"] in by_name:
            copy["x"] = by_name[copy["name"]]["x"]
            copy["y"] = by_name[copy["name"]]["y"]
        out_list.append(copy)
    return out_list


def generate_kdl(outputs: list[dict], primary_name: str) -> str:
    lines = [
        "// --- Nirakase: Managed Monitor & Output Configuration ---",
        "// Automatically generated and kept in sync by Nirakase Display Manager.",
        "// Manual overrides can be placed in ~/.config/niri/config.d/outputs.kdl.",
        "",
    ]
    for o in outputs:
        safe_name = str(o["name"]).replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'output "{safe_name}" {{')
        if not o.get("enabled", True):
            lines.append("    off")
        else:
            mode_cmd = str(o.get("mode") or o.get("modeCmd") or "").strip()
            if mode_cmd and MODE_RE.match(mode_cmd):
                lines.append(f'    mode "{mode_cmd}"')
            scale_val = o.get("scale", 1.0)
            lines.append(f"    scale {format_scale(scale_val)}")
            transform = normalize_transform(o.get("transform", "normal"))
            lines.append(f'    transform "{transform}"')
            x = round(float(o.get("x", 0)))
            y = round(float(o.get("y", 0)))
            lines.append(f"    position x={x} y={y}")
            if primary_name and o["name"] == primary_name:
                lines.append("    focus-at-startup")
        lines.append("}")
        lines.append("")
    return "\n".join(lines)


def resolve_best_mode_for_output(desired_mode: str, live_output: dict) -> str:
    """Validate desired mode against available modes on the output, picking exact match if available."""
    if not desired_mode:
        return ""
    parsed = parse_mode_cmd(desired_mode)
    if not parsed:
        return ""
    dw, dh, dhz = parsed
    modes = live_output.get("modes") if isinstance(live_output.get("modes"), list) else []
    if not modes:
        return desired_mode

    best = None
    best_diff = float("inf")
    for md in modes:
        mw = int(md.get("width", 0))
        mh = int(md.get("height", 0))
        m_mhz = int(md.get("refresh_rate", 60000))
        if mw != dw or mh != dh:
            continue
        if dhz is None:
            # Highest refresh rate for resolution
            diff = -m_mhz
        else:
            diff = abs((m_mhz / 1000.0) - dhz)
        if diff < best_diff:
            best_diff = diff
            best = md

    if best is not None and (dhz is None or best_diff <= 1.0):
        hz_str = f"{int(best['refresh_rate']) / 1000.0:.3f}"
        return f"{int(best['width'])}x{int(best['height'])}@{hz_str}"
    return ""


def live_matches_desired(raw_outputs: dict, desired_list: list[dict]) -> bool:
    for d in desired_list:
        name = d["name"]
        live = raw_outputs.get(name)
        if not live:
            continue
        logical = live.get("logical")
        live_enabled = logical is not None
        want_enabled = bool(d.get("enabled", True))
        if live_enabled != want_enabled:
            return False
        if not want_enabled:
            continue

        if int(logical.get("x", 0)) != int(d["x"]) or int(logical.get("y", 0)) != int(d["y"]):
            return False
        if abs(float(logical.get("scale", 1.0)) - float(d.get("scale", 1.0))) >= 0.01:
            return False
        if normalize_transform(logical.get("transform")) != normalize_transform(d.get("transform")):
            return False

        want_mode = parse_mode_cmd(d.get("mode", ""))
        if want_mode:
            modes = live.get("modes") or []
            cur_idx = live.get("current_mode")
            cur_md = modes[cur_idx] if isinstance(cur_idx, int) and 0 <= cur_idx < len(modes) else None
            if cur_md:
                cw = int(cur_md.get("width", 0))
                ch = int(cur_md.get("height", 0))
                chz = int(cur_md.get("refresh_rate", 60000)) / 1000.0
                if cw != want_mode[0] or ch != want_mode[1]:
                    return False
                if want_mode[2] is not None and abs(chz - want_mode[2]) > 0.15:
                    return False
    return True


def apply_positions_non_overlapping(raw_outputs: dict, desired_enabled: list[dict]) -> None:
    """Move outputs into final positions using two-phase staging if any intermediate overlap would occur."""
    current_rects: dict[str, dict] = {}
    for name, o in raw_outputs.items():
        log = o.get("logical")
        if log:
            current_rects[name] = {
                "name": name,
                "x": int(log.get("x", 0)),
                "y": int(log.get("y", 0)),
                "width": int(log.get("width", 1920)),
                "height": int(log.get("height", 1080)),
            }

    to_move = []
    for d in desired_enabled:
        name = d["name"]
        cur = current_rects.get(name)
        if not cur or cur["x"] != int(d["x"]) or cur["y"] != int(d["y"]):
            to_move.append(d)

    if not to_move:
        return

    # Check if moving sequentially in current order causes any intermediate overlap
    sim = {k: dict(v) for k, v in current_rects.items()}
    needs_staging = False
    for d in to_move:
        name = d["name"]
        target_rect = {
            "x": int(d["x"]),
            "y": int(d["y"]),
            "width": int(sim.get(name, d)["width"]),
            "height": int(sim.get(name, d)["height"]),
        }
        for other_name, other_rect in sim.items():
            if other_name != name and rects_overlap(target_rect, other_rect):
                needs_staging = True
                break
        if needs_staging:
            break
        sim[name] = {"name": name, **target_rect}

    if needs_staging:
        max_right = max((r["x"] + r["width"] for r in current_rects.values()), default=0)
        max_target_right = max((int(d["x"]) + int(d["width"]) for d in desired_enabled), default=0)
        stage_x = max(max_right, max_target_right) + 10000
        for d in to_move:
            w = int(current_rects.get(d["name"], d)["width"])
            niri_output(d["name"], "position", "set", str(stage_x), "0")
            stage_x += w + 500

    for d in desired_enabled:
        niri_output(d["name"], "position", "set", str(int(d["x"])), str(int(d["y"])))


def apply_configuration(
    desired_outputs: list[dict],
    primary_name: str,
    mirror_cfg: dict | None = None,
    persist: bool = True,
    keep_focus: str = "",
) -> dict:
    raw_outputs = run_niri_json("outputs") or {}
    if not raw_outputs:
        return {"ok": False, "error": "No Niri outputs detected"}

    fps = compute_fingerprints(raw_outputs)
    store = load_store()

    # Build normalized desired list for currently connected outputs only
    desired_by_name = {str(o["name"]): dict(o) for o in desired_outputs if o.get("name") in raw_outputs}
    normalized_list = []

    for name in sorted(raw_outputs.keys(), key=lambda k: (0 if is_internal_connector(k) else 1, k)):
        live = raw_outputs[name]
        logical = live.get("logical")
        entry = desired_by_name.get(name)
        if entry is None:
            # Keep existing live state for any connected output not explicitly passed
            modes = live.get("modes") or []
            cur_idx = live.get("current_mode")
            cur_md = modes[cur_idx] if isinstance(cur_idx, int) and 0 <= cur_idx < len(modes) else (modes[0] if modes else None)
            pw = int(cur_md["width"]) if cur_md else 1920
            ph = int(cur_md["height"]) if cur_md else 1080
            hz = f"{int(cur_md['refresh_rate']) / 1000.0:.3f}" if cur_md else "60.000"
            sc = float(logical["scale"]) if logical and logical.get("scale") else 1.0
            tr = normalize_transform(logical["transform"]) if logical else "normal"
            lw, lh = (int(logical["width"]), int(logical["height"])) if logical else compute_logical_size(pw, ph, sc, tr)
            entry = {
                "name": name,
                "enabled": logical is not None,
                "mode": f"{pw}x{ph}@{hz}",
                "scale": sc,
                "transform": tr,
                "x": int(logical["x"]) if logical else 0,
                "y": int(logical["y"]) if logical else 0,
                "width": lw,
                "height": lh,
            }
        else:
            enabled = bool(entry.get("enabled", True))
            scale = max(0.25, min(4.0, float(entry.get("scale", 1.0))))
            transform = normalize_transform(entry.get("transform", "normal"))
            raw_mode = str(entry.get("mode") or entry.get("modeCmd") or "").strip()
            valid_mode = resolve_best_mode_for_output(raw_mode, live)
            if not valid_mode:
                modes = live.get("modes") or []
                cur_idx = live.get("current_mode")
                cur_md = modes[cur_idx] if isinstance(cur_idx, int) and 0 <= cur_idx < len(modes) else (modes[0] if modes else None)
                if cur_md:
                    valid_mode = f"{int(cur_md['width'])}x{int(cur_md['height'])}@{int(cur_md['refresh_rate']) / 1000.0:.3f}"
            parsed_m = parse_mode_cmd(valid_mode)
            if parsed_m:
                lw, lh = compute_logical_size(parsed_m[0], parsed_m[1], scale, transform)
            else:
                lw = int(entry.get("width", logical["width"] if logical else 1920))
                lh = int(entry.get("height", logical["height"] if logical else 1080))
            entry = {
                "name": name,
                "enabled": enabled,
                "mode": valid_mode,
                "scale": scale,
                "transform": transform,
                "x": round(float(entry.get("x", 0))),
                "y": round(float(entry.get("y", 0))),
                "width": lw,
                "height": lh,
            }
        normalized_list.append(entry)

    # Safety guard: never allow all outputs to be disabled
    if not any(o["enabled"] for o in normalized_list):
        normalized_list[0]["enabled"] = True

    # Ensure primary points to a connected (preferably enabled) output
    enabled_names = [o["name"] for o in normalized_list if o["enabled"]]
    if primary_name not in enabled_names:
        primary_name = enabled_names[0]

    # Mirror handling: ensure both mirror source and target are enabled and placed non-overlapping
    mirror_enabled = bool(mirror_cfg and mirror_cfg.get("enabled"))
    mirror_source = str((mirror_cfg or {}).get("source") or primary_name)
    mirror_target = str((mirror_cfg or {}).get("target") or "")
    if mirror_enabled:
        if mirror_source not in raw_outputs:
            mirror_source = primary_name
        if not mirror_target or mirror_target not in raw_outputs or mirror_target == mirror_source:
            others = [o["name"] for o in normalized_list if o["name"] != mirror_source]
            mirror_target = others[0] if others else ""
        if mirror_target:
            for o in normalized_list:
                if o["name"] in (mirror_source, mirror_target):
                    o["enabled"] = True
        else:
            mirror_enabled = False

    normalized_list = sanitize_layout_positions(normalized_list, primary_name)

    # Remember current focused output before changing anything
    focus_target = keep_focus if keep_focus in enabled_names else get_focused_output_name()
    if focus_target not in enabled_names:
        focus_target = primary_name

    # Stop wl-mirror before changing outputs
    stop_wl_mirror()

    # Persist to profile store and outputs.kdl if requested
    applied_via = "ipc"
    if persist:
        save_profile_to_store(store, raw_outputs, fps, normalized_list, primary_name, {
            "enabled": mirror_enabled,
            "source": mirror_source if mirror_enabled else "",
            "target": mirror_target if mirror_enabled else "",
        })
        kdl_text = generate_kdl(normalized_list, primary_name)
        atomic_write_text(outputs_kdl_path(), kdl_text)

        # Give Niri a short moment to auto-reload outputs.kdl atomically
        time.sleep(0.14)
        fresh = run_niri_json("outputs") or {}
        if live_matches_desired(fresh, normalized_list):
            applied_via = "kdl-reload"
            raw_outputs = fresh

    if applied_via != "kdl-reload":
        # 1. Enable outputs that must be ON first (before disabling anything)
        changed_modeset = False
        for o in normalized_list:
            if o["enabled"] and raw_outputs.get(o["name"], {}).get("logical") is None:
                niri_output(o["name"], "on")
                changed_modeset = True

        # 2. Apply mode, scale, transform only where different
        for o in normalized_list:
            if not o["enabled"]:
                continue
            live = raw_outputs.get(o["name"], {})
            logical = live.get("logical") or {}

            if o["mode"]:
                want_m = parse_mode_cmd(o["mode"])
                modes = live.get("modes") or []
                cur_idx = live.get("current_mode")
                cur_md = modes[cur_idx] if isinstance(cur_idx, int) and 0 <= cur_idx < len(modes) else None
                need_mode = True
                if cur_md and want_m:
                    chz = int(cur_md.get("refresh_rate", 60000)) / 1000.0
                    if (
                        int(cur_md.get("width", 0)) == want_m[0]
                        and int(cur_md.get("height", 0)) == want_m[1]
                        and (want_m[2] is None or abs(chz - want_m[2]) <= 0.15)
                    ):
                        need_mode = False
                if need_mode:
                    niri_output(o["name"], "mode", o["mode"])
                    changed_modeset = True

            live_scale = float(logical.get("scale", 1.0)) if logical else 1.0
            if not logical or abs(live_scale - o["scale"]) >= 0.01:
                niri_output(o["name"], "scale", format_scale(o["scale"]))
                changed_modeset = True

            live_tr = normalize_transform(logical.get("transform")) if logical else "normal"
            if not logical or live_tr != o["transform"]:
                niri_output(o["name"], "transform", o["transform"])
                changed_modeset = True

        # 3. Disable outputs that must be OFF
        for o in normalized_list:
            if not o["enabled"] and raw_outputs.get(o["name"], {}).get("logical") is not None:
                niri_output(o["name"], "off")
                changed_modeset = True

        if changed_modeset:
            time.sleep(0.10)

        # 4. Re-query exact logical sizes and place enabled outputs without overlaps
        fresh = run_niri_json("outputs") or raw_outputs
        for o in normalized_list:
            if o["enabled"]:
                log = (fresh.get(o["name"]) or {}).get("logical")
                if log:
                    o["width"] = int(log.get("width", o["width"]))
                    o["height"] = int(log.get("height", o["height"]))

        normalized_list = sanitize_layout_positions(normalized_list, primary_name)
        desired_enabled = [o for o in normalized_list if o["enabled"]]
        apply_positions_non_overlapping(fresh, desired_enabled)

        # If persist was requested and logical sizes slightly adjusted after modeset, re-sync KDL & store
        if persist:
            save_profile_to_store(store, fresh, fps, normalized_list, primary_name, {
                "enabled": mirror_enabled,
                "source": mirror_source if mirror_enabled else "",
                "target": mirror_target if mirror_enabled else "",
            })
            atomic_write_text(outputs_kdl_path(), generate_kdl(normalized_list, primary_name))

    # Start wl-mirror if mirroring
    mirror_started = False
    if mirror_enabled and mirror_source and mirror_target:
        mirror_started = start_wl_mirror(mirror_source, mirror_target)

    # Restore focus to the output where the user was working (prevents focus jumps)
    if focus_target:
        time.sleep(0.05)
        cur_focus = get_focused_output_name()
        if cur_focus and cur_focus != focus_target:
            niri_action("focus-monitor", focus_target)

    sync_wallpaper()

    return {
        "ok": True,
        "persisted": persist,
        "applied_via": applied_via,
        "primary": primary_name,
        "mirror_active": mirror_started,
    }


def save_profile_to_store(
    store: dict,
    raw_outputs: dict,
    fps: dict[str, str],
    normalized_list: list[dict],
    primary_name: str,
    mirror_cfg: dict,
) -> None:
    topo_key, conn_key = topology_keys(raw_outputs, fps)
    profile_outputs = {}
    output_defaults = store.setdefault("output_defaults", {})

    for o in normalized_list:
        name = o["name"]
        fp = fps[name]
        profile_outputs[fp] = {
            "connector": name,
            "enabled": bool(o["enabled"]),
            "mode": str(o.get("mode") or ""),
            "scale": round(float(o.get("scale", 1.0)), 4),
            "transform": normalize_transform(o.get("transform", "normal")),
            "x": int(o.get("x", 0)),
            "y": int(o.get("y", 0)),
        }
        if o["enabled"]:
            output_defaults[fp] = {
                "mode": str(o.get("mode") or ""),
                "scale": round(float(o.get("scale", 1.0)), 4),
                "transform": normalize_transform(o.get("transform", "normal")),
            }

    store.setdefault("profiles", {})[topo_key] = {
        "connectors_key": conn_key,
        "updated_at": int(time.time()),
        "primary": primary_name,
        "primary_fp": fps.get(primary_name, ""),
        "mirror": {
            "enabled": bool(mirror_cfg.get("enabled")),
            "source_fp": fps.get(mirror_cfg.get("source", ""), ""),
            "target_fp": fps.get(mirror_cfg.get("target", ""), ""),
            "source": mirror_cfg.get("source", ""),
            "target": mirror_cfg.get("target", ""),
        },
        "outputs": profile_outputs,
    }
    save_store(store)


def find_matching_profile(store: dict, raw_outputs: dict, fps: dict[str, str]) -> tuple[str | None, dict | None]:
    topo_key, conn_key = topology_keys(raw_outputs, fps)
    profiles = store.get("profiles") or {}
    if topo_key in profiles:
        return topo_key, profiles[topo_key]
    # Fallback: match by exact sorted connector names if hardware EDID changed
    for k, prof in profiles.items():
        if isinstance(prof, dict) and prof.get("connectors_key") == conn_key:
            return k, prof
    return None, None


def profile_to_desired_outputs(profile: dict, raw_outputs: dict, fps: dict[str, str]) -> tuple[list[dict], str, dict]:
    prof_outs = profile.get("outputs") or {}
    by_conn = {
        v.get("connector"): v
        for v in prof_outs.values()
        if isinstance(v, dict) and v.get("connector")
    }

    desired = []
    for name in sorted(raw_outputs.keys(), key=lambda k: (0 if is_internal_connector(k) else 1, k)):
        fp = fps[name]
        saved = prof_outs.get(fp) or by_conn.get(name)
        if not saved:
            continue
        desired.append(
            {
                "name": name,
                "enabled": bool(saved.get("enabled", True)),
                "mode": str(saved.get("mode") or ""),
                "scale": float(saved.get("scale", 1.0)),
                "transform": normalize_transform(saved.get("transform", "normal")),
                "x": int(saved.get("x", 0)),
                "y": int(saved.get("y", 0)),
            }
        )

    # Resolve primary output by fingerprint first, then connector
    primary_fp = str(profile.get("primary_fp") or "")
    primary_name = ""
    if primary_fp:
        for name, fp in fps.items():
            if fp == primary_fp:
                primary_name = name
                break
    if not primary_name:
        cand = str(profile.get("primary") or "")
        if cand in raw_outputs:
            primary_name = cand

    # Resolve mirror source/target by fingerprint first
    m_raw = profile.get("mirror") or {}
    m_src = ""
    m_tgt = ""
    if m_raw.get("enabled"):
        for name, fp in fps.items():
            if fp == m_raw.get("source_fp"):
                m_src = name
            if fp == m_raw.get("target_fp"):
                m_tgt = name
        if not m_src and m_raw.get("source") in raw_outputs:
            m_src = m_raw["source"]
        if not m_tgt and m_raw.get("target") in raw_outputs:
            m_tgt = m_raw["target"]

    mirror_cfg = {
        "enabled": bool(m_raw.get("enabled")) and bool(m_src) and bool(m_tgt) and m_src != m_tgt,
        "source": m_src,
        "target": m_tgt,
    }
    return desired, primary_name, mirror_cfg


# ── CLI Commands ─────────────────────────────────────────────────────────────


def cmd_query(_args) -> dict:
    raw_outputs = run_niri_json("outputs") or {}
    focused = get_focused_output_name()
    wlm = get_wl_mirror_state()
    store = load_store()
    fps = compute_fingerprints(raw_outputs)
    topo_key, conn_key = topology_keys(raw_outputs, fps)
    structured = structure_outputs(raw_outputs, fps, store)

    prof_key, prof = find_matching_profile(store, raw_outputs, fps)
    saved_primary = ""
    if prof:
        pfp = prof.get("primary_fp") or ""
        for name, fp in fps.items():
            if fp == pfp:
                saved_primary = name
                break
        if not saved_primary and prof.get("primary") in raw_outputs:
            saved_primary = prof["primary"]

    return {
        "ok": True,
        "has_wlm": wlm["installed"],
        "mirror": {
            "active": wlm["active"],
            "source": wlm["source"],
            "target": wlm["target"],
        },
        "focused_output": focused,
        "topology_key": topo_key,
        "connectors_key": conn_key,
        "has_saved_profile": prof is not None,
        "saved_profile_key": prof_key or "",
        "saved_primary": saved_primary,
        "outputs": structured,
    }


def cmd_apply(args) -> dict:
    raw_payload = sys.stdin.read() if args.payload == "-" else args.payload
    payload = json.loads(raw_payload)
    outputs = payload.get("outputs") or []
    primary = str(payload.get("primary") or "")
    mirror = payload.get("mirror") or {}
    persist = bool(payload.get("persist", True))
    keep_focus = str(payload.get("keep_focus") or "")
    with state_lock():
        return apply_configuration(
            desired_outputs=outputs,
            primary_name=primary,
            mirror_cfg=mirror,
            persist=persist,
            keep_focus=keep_focus,
        )


def cmd_save_current(args) -> dict:
    with state_lock():
        raw_outputs = run_niri_json("outputs") or {}
        if not raw_outputs:
            return {"ok": False, "error": "No Niri outputs detected"}
        fps = compute_fingerprints(raw_outputs)
        store = load_store()
        structured = structure_outputs(raw_outputs, fps, store)
        wlm = get_wl_mirror_state()

        enabled_names = [o["name"] for o in structured if o["enabled"]]
        primary = args.primary if args.primary in enabled_names else (
            get_focused_output_name() if get_focused_output_name() in enabled_names else (
                enabled_names[0] if enabled_names else structured[0]["name"]
            )
        )
        normalized = [
            {
                "name": o["name"],
                "enabled": o["enabled"],
                "mode": o["modeCmd"],
                "scale": o["scale"],
                "transform": o["transform"],
                "x": o["x"],
                "y": o["y"],
                "width": o["width"],
                "height": o["height"],
            }
            for o in structured
        ]
        normalized = sanitize_layout_positions(normalized, primary)
        save_profile_to_store(
            store,
            raw_outputs,
            fps,
            normalized,
            primary,
            {
                "enabled": wlm["active"],
                "source": wlm["source"],
                "target": wlm["target"],
            },
        )
        atomic_write_text(outputs_kdl_path(), generate_kdl(normalized, primary))
        return {"ok": True, "primary": primary, "saved": True}


def cmd_apply_preset(args) -> dict:
    with state_lock():
        raw_outputs = run_niri_json("outputs") or {}
        if not raw_outputs:
            return {"ok": False, "error": "No Niri outputs detected"}
        fps = compute_fingerprints(raw_outputs)
        store = load_store()
        structured = structure_outputs(raw_outputs, fps, store)

        if len(structured) == 1:
            o = structured[0]
            return apply_configuration(
                desired_outputs=[
                    {
                        "name": o["name"],
                        "enabled": True,
                        "mode": o["modeCmd"],
                        "scale": o["scale"],
                        "transform": o["transform"],
                        "x": 0,
                        "y": 0,
                    }
                ],
                primary_name=o["name"],
                mirror_cfg={"enabled": False},
                persist=True,
                keep_focus=args.keep_focus or o["name"],
            )

        names = [o["name"] for o in structured]
        prim = args.primary if args.primary in names else names[0]
        sec = args.secondary if (args.secondary in names and args.secondary != prim) else next(
            (n for n in names if n != prim), names[0]
        )
        by_name = {o["name"]: o for o in structured}
        mode = args.mode

        # Build desired list preserving each monitor's mode, scale, transform
        p_out = by_name[prim]
        s_out = by_name[sec]
        pw, ph = p_out["width"], p_out["height"]
        sw, sh = s_out["width"], s_out["height"]

        desired = []
        mirror_cfg = {"enabled": False, "source": "", "target": ""}

        if mode == "primary-only":
            for o in structured:
                desired.append({
                    "name": o["name"],
                    "enabled": o["name"] == prim,
                    "mode": o["modeCmd"],
                    "scale": o["scale"],
                    "transform": o["transform"],
                    "x": 0,
                    "y": 0,
                })
        elif mode == "secondary-only":
            for o in structured:
                desired.append({
                    "name": o["name"],
                    "enabled": o["name"] == sec,
                    "mode": o["modeCmd"],
                    "scale": o["scale"],
                    "transform": o["transform"],
                    "x": 0,
                    "y": 0,
                })
            prim = sec
        else:
            # Center-align along shared axis for ergonomic cursor travel across different resolutions
            if mode == "extend-right":
                p_pos = (0, max(0, (sh - ph) // 2))
                s_pos = (pw, max(0, (ph - sh) // 2))
                cur_x = pw + sw
            elif mode == "extend-left":
                s_pos = (0, max(0, (ph - sh) // 2))
                p_pos = (sw, max(0, (sh - ph) // 2))
                cur_x = sw + pw
            elif mode == "extend-above":
                s_pos = (max(0, (pw - sw) // 2), 0)
                p_pos = (max(0, (sw - pw) // 2), sh)
                cur_x = max(pw, sw)
            elif mode == "extend-below":
                p_pos = (max(0, (sw - pw) // 2), 0)
                s_pos = (max(0, (pw - sw) // 2), ph)
                cur_x = max(pw, sw)
            elif mode == "mirror":
                p_pos = (0, 0)
                s_pos = (pw, 0)
                cur_x = pw + sw
                mirror_cfg = {"enabled": True, "source": prim, "target": sec}
            else:
                p_pos = (0, 0)
                s_pos = (pw, 0)
                cur_x = pw + sw

            for o in structured:
                if o["name"] == prim:
                    px, py = p_pos
                elif o["name"] == sec:
                    px, py = s_pos
                else:
                    px, py = cur_x, 0
                    cur_x += o["width"]
                desired.append({
                    "name": o["name"],
                    "enabled": True,
                    "mode": o["modeCmd"],
                    "scale": o["scale"],
                    "transform": o["transform"],
                    "x": px,
                    "y": py,
                })

        return apply_configuration(
            desired_outputs=desired,
            primary_name=prim,
            mirror_cfg=mirror_cfg,
            persist=True,
            keep_focus=args.keep_focus or "",
        )


def cmd_restore(_args) -> dict:
    with state_lock():
        raw_outputs = run_niri_json("outputs") or {}
        if not raw_outputs:
            return {"ok": False, "matched": False, "applied": False, "error": "No Niri outputs detected"}

        fps = compute_fingerprints(raw_outputs)
        store = load_store()

        # Emergency safety net: if every connected output is currently OFF, turn on internal or first output
        any_enabled = any(o.get("logical") is not None for o in raw_outputs.values())
        if not any_enabled:
            fallback = next((k for k in sorted(raw_outputs.keys()) if is_internal_connector(k)), min(raw_outputs.keys()))
            niri_output(fallback, "on")
            time.sleep(0.12)
            raw_outputs = run_niri_json("outputs") or raw_outputs

        prof_key, prof = find_matching_profile(store, raw_outputs, fps)
        if not prof:
            # No exact topology profile saved yet; still ensure at least one output is on & sync KDL safely
            return {
                "ok": True,
                "matched": False,
                "applied": not any_enabled,
                "profile_key": "",
            }

        desired, primary_name, mirror_cfg = profile_to_desired_outputs(prof, raw_outputs, fps)
        if not desired:
            return {"ok": True, "matched": False, "applied": False, "profile_key": ""}

        # Resolve modes and logical dimensions to check if live state already matches
        structured_desired = []
        for d in desired:
            live = raw_outputs.get(d["name"], {})
            valid_mode = resolve_best_mode_for_output(d["mode"], live)
            parsed_m = parse_mode_cmd(valid_mode)
            if parsed_m:
                lw, lh = compute_logical_size(parsed_m[0], parsed_m[1], d["scale"], d["transform"])
            else:
                log = live.get("logical") or {}
                lw, lh = int(log.get("width", 1920)), int(log.get("height", 1080))
            structured_desired.append({**d, "mode": valid_mode, "width": lw, "height": lh})

        structured_desired = sanitize_layout_positions(structured_desired, primary_name)
        wlm = get_wl_mirror_state()
        mirror_matches = (
            bool(wlm["active"]) == bool(mirror_cfg["enabled"])
            and (
                not mirror_cfg["enabled"]
                or (wlm["source"] == mirror_cfg["source"] and wlm["target"] == mirror_cfg["target"])
            )
        )

        if live_matches_desired(raw_outputs, structured_desired) and mirror_matches:
            # Keep managed outputs.kdl aligned with active topology
            atomic_write_text(outputs_kdl_path(), generate_kdl(structured_desired, primary_name))
            return {
                "ok": True,
                "matched": True,
                "applied": False,
                "profile_key": prof_key or "",
                "primary": primary_name,
            }

        res = apply_configuration(
            desired_outputs=structured_desired,
            primary_name=primary_name,
            mirror_cfg=mirror_cfg,
            persist=True,
            keep_focus=get_focused_output_name(),
        )
        return {
            "ok": bool(res.get("ok")),
            "matched": True,
            "applied": True,
            "profile_key": prof_key or "",
            "primary": res.get("primary", primary_name),
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Nirakase Display Manager backend for Niri")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("query", help="Query live outputs, mirror status, and saved profile match")

    p_apply = sub.add_parser("apply", help="Apply a display configuration JSON payload")
    p_apply.add_argument("--payload", default="-", help="JSON payload string or '-' to read from stdin")

    p_save = sub.add_parser("save-current", help="Persist current live Niri output state")
    p_save.add_argument("--primary", default="", help="Preferred primary output name")

    p_preset = sub.add_parser("apply-preset", help="Apply a multi-monitor preset and persist")
    p_preset.add_argument("mode", help="Preset mode (extend-right, extend-left, extend-above, extend-below, mirror, primary-only, secondary-only)")
    p_preset.add_argument("--primary", default="", help="Primary output name")
    p_preset.add_argument("--secondary", default="", help="Secondary output name")
    p_preset.add_argument("--keep-focus", default="", help="Monitor name to keep focused")

    sub.add_parser("restore", help="Restore saved display profile matching the connected topology")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    handlers = {
        "query": cmd_query,
        "apply": cmd_apply,
        "save-current": cmd_save_current,
        "apply-preset": cmd_apply_preset,
        "restore": cmd_restore,
    }
    try:
        result = handlers[args.command](args)
        sys.stdout.write(json.dumps(result) + "\n")
        sys.stdout.flush()
        return 0 if result.get("ok", True) else 1
    except (OSError, RuntimeError, ValueError, TypeError, subprocess.SubprocessError) as exc:
        sys.stdout.write(json.dumps({"ok": False, "error": str(exc)}) + "\n")
        sys.stdout.flush()
        return 1


if __name__ == "__main__":
    sys.exit(main())
