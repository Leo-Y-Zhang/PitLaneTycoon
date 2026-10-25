"""Play-test Pit Lane Tycoon in Roblox Studio and print the result.

    python tools/studio-test/run.py PitLaneTycoon.rbxlx [--shots DIR]

Installs PitLaneSmokeTest.lua as a local plugin, opens the place in Studio, waits for the
plugin's RESULT line in Studio's log, then removes the plugin. Exit code 0 means every check
passed and the game logged no errors. Studio must be installed and signed in (Windows).
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

TAG = "[PLT-TEST]"
HERE = Path(__file__).resolve().parent
ROBLOX = Path(os.environ["LOCALAPPDATA"]) / "Roblox"
PLUGIN = ROBLOX / "Plugins" / "PitLaneSmokeTest.lua"


def studio_exe() -> Path:
    found = sorted(ROBLOX.glob("Versions/*/RobloxStudioBeta.exe"), key=lambda p: p.stat().st_mtime)
    if not found:
        sys.exit("Roblox Studio is not installed (roblox.com/create).")
    return found[-1]


WINDOW_SHOT = r'''
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class StudioWindow {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
}
"@
[StudioWindow]::SetProcessDPIAware() | Out-Null  # real pixels on a scaled display
$h = (Get-Process -Id __PID__).MainWindowHandle
$r = New-Object StudioWindow+RECT
if ($h -ne 0 -and [StudioWindow]::GetWindowRect($h, [ref]$r)) {
  $i = New-Object System.Drawing.Bitmap ($r.Right - $r.Left), ($r.Bottom - $r.Top)
  $g = [System.Drawing.Graphics]::FromImage($i)
  $hdc = $g.GetHdc()
  # 2 = PW_RENDERFULLCONTENT: draws Studio's own window even when another window covers it
  [StudioWindow]::PrintWindow($h, $hdc, 2) | Out-Null
  $g.ReleaseHdc($hdc)
  $i.Save('__PATH__')
}
'''


def screenshot(pid: int, path: Path) -> None:
    """Capture only the Studio window this run opened, never the rest of the screen or a
    window lying on top of it."""
    script = WINDOW_SHOT.replace("__PID__", str(pid)).replace("__PATH__", str(path))
    env = {k: v for k, v in os.environ.items() if k != "PSModulePath"}
    subprocess.run(["powershell.exe", "-NoProfile", "-Command", script], env=env, check=False)


def screen_locked() -> bool:
    """The lock screen (LogonUI) is up. Studio then draws its viewport 1 px tall, so the
    client's layout checks fail and screenshots come out empty."""
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq LogonUI.exe", "/NH"],
                         capture_output=True, text=True, check=False).stdout
    return "LogonUI.exe" in out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("place", type=Path)
    ap.add_argument("--shots", type=Path, help="save a screenshot of the Studio window here (it shows your avatar)")
    ap.add_argument("--timeout", type=int, default=420)
    ap.add_argument("--keep-open", action="store_true", help="leave the Studio window open afterwards")
    ap.add_argument("--audio", action="store_true",
                    help="check every sound id in Config.Audio was made by Roblox, and list Roblox-made candidates")
    ap.add_argument("--photos", action="store_true",
                    help="take thumbnail shots of a finished garage instead of testing (needs --shots)")
    a = ap.parse_args()
    place = a.place.resolve()
    if not place.exists():
        sys.exit(f"no such place file: {place}")

    PLUGIN.parent.mkdir(parents=True, exist_ok=True)
    source = (HERE / "PitLaneSmokeTest.lua").read_text(encoding="utf-8")
    if a.photos:
        if not a.shots:
            sys.exit("--photos needs --shots DIR")
        source = source.replace('local SCENARIO = "smoke"', 'local SCENARIO = "photo"', 1)
    elif a.audio:
        source = source.replace('local SCENARIO = "smoke"', 'local SCENARIO = "audio"', 1)
    PLUGIN.write_text(source, encoding="utf-8")
    locked = screen_locked()
    if locked:
        print("NOTE the screen is locked: the server checks hold, but the client layout checks"
              " and any screenshots are not meaningful until it is unlocked")
    started = time.time()
    # skip what is already in Studio's logs, or an earlier run's RESULT would be read as this one's
    seen: dict[Path, int] = {log: log.stat().st_size for log in (ROBLOX / "logs").glob("*Studio*.log")}
    result = None
    studio = None
    client_fails = 0
    try:
        studio = subprocess.Popen([str(studio_exe()), str(place)])
        while time.time() - started < a.timeout and result is None:
            time.sleep(2)
            for log in (ROBLOX / "logs").glob("*Studio*.log"):
                if log.stat().st_mtime < started - 5:
                    continue
                data = log.read_bytes()
                offset = seen.get(log, 0)
                seen[log] = len(data)
                for line in data[offset:].decode("utf-8", "replace").splitlines():
                    if TAG not in line:
                        continue
                    text = line[line.index(TAG) + len(TAG):].strip()
                    if text.startswith("RESULT "):
                        result = json.loads(text[len("RESULT "):])
                    else:
                        print(text, flush=True)
                        client_fails += text.startswith("CLIENT-FAIL")
                        if text.startswith("SHOT") and a.shots:
                            a.shots.mkdir(parents=True, exist_ok=True)
                            name = text[4:].strip() or "studio-play"
                            screenshot(studio.pid, a.shots / f"{name}.png")
    finally:
        PLUGIN.unlink(missing_ok=True)
        # close only the Studio window this run opened
        if studio and not a.keep_open and studio.poll() is None:
            studio.terminate()

    if result is None:
        print(f"no result after {a.timeout} s: is Studio signed in and the place open?")
        return 2
    if not result.get("ok"):
        print("the play test could not start:", result.get("result"))
        return 2
    r = result["result"]
    print(f"\n{r['passed']}/{r['total']} checks passed, {client_fails} client checks failed, {r['errors']} errors"
          + (" (screen locked: client checks not meaningful)" if locked else ""))
    return 0 if r["passed"] == r["total"] and not client_fails and not r["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
