"""Play-test Pit Lane Tycoon in Roblox Studio and print the result.

    python tools/studio-test/run.py PitLaneTycoon.rbxlx [--shots DIR]

Installs PitLaneSmokeTest.lua as a local plugin, opens the place in Studio, waits for the
plugin's RESULT line in Studio's log, then removes the plugin. Exit code 0 means every check
passed and the game logged no errors. Studio must be installed and signed in (Windows).
"""

import argparse
import json
import os
import shutil
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


def screenshot(path: Path) -> None:
    script = (
        "Add-Type -AssemblyName System.Windows.Forms,System.Drawing;"
        "$b=[System.Windows.Forms.SystemInformation]::VirtualScreen;"
        "$i=New-Object System.Drawing.Bitmap $b.Width,$b.Height;"
        "$g=[System.Drawing.Graphics]::FromImage($i);"
        "$g.CopyFromScreen($b.Left,$b.Top,0,0,$i.Size);"
        f"$i.Save('{path}');"
    )
    env = {k: v for k, v in os.environ.items() if k != "PSModulePath"}
    subprocess.run(["powershell.exe", "-NoProfile", "-Command", script], env=env, check=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("place", type=Path)
    ap.add_argument("--shots", type=Path, help="save desktop screenshots here during the test")
    ap.add_argument("--timeout", type=int, default=420)
    ap.add_argument("--keep-open", action="store_true", help="leave the Studio window open afterwards")
    a = ap.parse_args()
    place = a.place.resolve()
    if not place.exists():
        sys.exit(f"no such place file: {place}")

    PLUGIN.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HERE / "PitLaneSmokeTest.lua", PLUGIN)
    started = time.time()
    seen: dict[Path, int] = {}
    result = None
    studio = None
    try:
        studio = subprocess.Popen([str(studio_exe()), str(place)])
        shot = 0
        next_shot = started + 45
        while time.time() - started < a.timeout and result is None:
            time.sleep(2)
            if a.shots and time.time() >= next_shot and shot < 6:
                a.shots.mkdir(parents=True, exist_ok=True)
                shot += 1
                screenshot(a.shots / f"studio-{shot}.png")
                next_shot = time.time() + 20
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
                        if text == "SHOT" and a.shots:
                            a.shots.mkdir(parents=True, exist_ok=True)
                            screenshot(a.shots / "studio-play.png")
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
    print(f"\n{r['passed']}/{r['total']} checks passed, {r['errors']} errors")
    return 0 if r["passed"] == r["total"] and not r["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
