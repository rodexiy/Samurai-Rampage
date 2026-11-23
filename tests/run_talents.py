"""Exercise production talents, bandages and execution healing without live saves."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "Config": "src/ReplicatedStorage/SkillTreeConfig.luau",
    "Talents": "src/ServerStorage/Services/TalentService.luau",
    "Bandage": "src/ServerStorage/Services/ToolService/Health/Bandage.luau",
    "Execution": "src/ServerStorage/Services/ExecutionService.luau",
    "Buffs": "src/ServerStorage/Services/BuffService.luau",
}


def literal(value: str) -> str:
    equals = "="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("luau", nargs="?", default=shutil.which("luau"))
    args = parser.parse_args()
    if not args.luau:
        parser.error("Pass the path to the Luau CLI executable.")
    sources = ",\n".join(f"{key} = {literal((ROOT / path).read_text(encoding='utf-8'))}" for key, path in FILES.items())
    test = literal((ROOT / "tests/TalentService.spec.luau").read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="samurai-talent-tests-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(f"local Sources = {{{sources}}}\nprint(assert(loadstring({test}))()(Sources))\n", encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
