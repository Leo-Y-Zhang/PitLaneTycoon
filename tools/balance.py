"""Print how long each purchase takes in Pit Lane Tycoon, and fail if the pacing breaks.

    python tools/balance.py [path/to/Config.luau]

Reads the production line from src/shared/Config.luau and plays it greedily: the next item
is bought as soon as the factory has earned its price. Times are minutes of income with no
passes, friends or happy hour, and no walking, so a real player is a little slower.
Exit code 1 means a check below failed (CI runs this on every push).
"""

import re
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / "src" / "shared" / "Config.luau"
SEASONS = 5
FIRST_SEASON_MINUTES = (45, 90)  # long enough to matter, short enough to finish in a sitting
MAX_STEP_MINUTES = 8  # no single purchase should feel like a wall
CONVEYOR_HALF = 22  # machines must sit on the conveyor (48 studs long, ends at +-24)


def number(text: str, name: str) -> float:
    m = re.search(rf"^Config\.{name} = ([\d.]+)", text, re.M)
    if not m:
        sys.exit(f"Config.{name} not found")
    return float(m.group(1))


def items(text: str) -> list[dict]:
    block = text[text.index("Config.Items = {"):]
    block = block[: block.index("} :: { Item }")]
    out = []
    for line in block.splitlines():
        if not line.strip().startswith("{ key"):
            continue
        item = {k: v for k, v in re.findall(r'(\w+) = "([^"]*)"', line)}
        item.update({k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+)", line)})
        out.append(item)
    return out


def income(line: list[dict], bought: set[str], base_speed: float, mult: float) -> float:
    speed = max([base_speed] + [i["speed"] for i in line if i["kind"] == "speed" and i["key"] in bought])
    upgrade = 1.0
    for i in line:
        if i["kind"] == "upgrade" and i["key"] in bought:
            upgrade *= i["mult"]
    per_min = 0.0
    for i in line:
        if i["kind"] == "press" and i["key"] in bought:
            tune = 1.0
            for t in line:
                if t["kind"] == "tune" and t["key"] in bought and t["target"] == i["key"]:
                    tune *= t["mult"]
            per_min += i["value"] * tune / (i["every"] * base_speed / speed) * 60
    return per_min * upgrade * mult


def money(n: float) -> str:
    for unit, size in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= size:
            return f"${n / size:.1f}{unit}"
    return f"${n:.0f}"


def main() -> int:
    text = Path(sys.argv[1] if len(sys.argv) > 1 else CONFIG).read_text(encoding="utf-8")
    line = items(text)
    base_speed = number(text, "BaseConveyorSpeed")
    bonus = number(text, "SeasonBonus")
    season_base = number(text, "SeasonCostBase")
    problems = []

    keys = [i["key"] for i in line]
    if line[-1]["kind"] != "trophy":
        problems.append("the trophy must be the last item")
    for i in line:
        if i["kind"] == "tune" and i["target"] not in keys[: keys.index(i["key"])]:
            problems.append(f"{i['key']} tunes {i['target']}, which is not earlier in the line")
    presses = [i for i in line if i["kind"] == "press"]
    gates = [i for i in line if i["kind"] == "upgrade"]
    for group, gap in ((presses, 3), (gates, 2.4)):
        xs = sorted(i["x"] for i in group)
        if any(b - a < gap for a, b in zip(xs, xs[1:])):
            problems.append(f"machines closer than {gap} studs: {xs}")
    if any(abs(i["x"]) > CONVEYOR_HALF for i in presses + gates):
        problems.append("a machine sits off the end of the conveyor")
    # a gate only multiplies parts that start upstream of it, and income assumes every part
    # passes every gate
    if presses and gates and min(g["x"] for g in gates) < max(p["x"] for p in presses) + 1.5:
        problems.append("an upgrade gate sits upstream of a press")

    for season in range(SEASONS):
        mult = 1 + season * bonus
        here = [i for i in line if i.get("season", 0) <= season]
        bought, cash, total = {here[0]["key"]}, 0.0, 0.0
        print(f"\nSeason {season + 1} (x{mult:g})")
        steps = here[1:] + [{"key": "new season", "name": "Cash for the next season", "cost": season_base * (season + 1)}]
        for i in steps:
            rate = income(line, bought, base_speed, mult)
            minutes = max(0.0, i["cost"] - cash) / rate
            cash = max(0.0, cash - i["cost"]) if cash > i["cost"] else 0.0
            total += minutes
            bought.add(i["key"])
            flag = ""
            if minutes > MAX_STEP_MINUTES:
                flag = "  <-- too slow"
                problems.append(f"season {season + 1}: {i['name']} takes {minutes:.1f} min")
            print(f"  {i['name']:<26} {money(i['cost']):>8}  {minutes:4.1f} min  (total {total:5.1f}){flag}")
        if season == 0 and not FIRST_SEASON_MINUTES[0] <= total <= FIRST_SEASON_MINUTES[1]:
            problems.append(f"season 1 takes {total:.0f} min; aim for {FIRST_SEASON_MINUTES[0]}-{FIRST_SEASON_MINUTES[1]}")

    for p in problems:
        print("FAIL", p)
    print("\nOK" if not problems else f"\n{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
