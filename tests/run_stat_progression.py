"""Run the real Luau progression modules with isolated Roblox dependencies."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "Config": "src/ReplicatedStorage/StatProgression.luau",
    "Profile": "src/ServerStorage/Services/Data/ProfileTemplate.luau",
    "StatService": "src/ServerStorage/Services/StatService.luau",
    "SkillTreeService": "src/ServerStorage/Services/SkillTreeService.luau",
    "ValuesService": "src/ServerStorage/Services/ValuesService.luau",
    "DamageService": "src/ServerStorage/Services/DamageService.luau",
    "SkillService": "src/ServerStorage/Services/SkillService/init.luau",
    "PureTests": "tests/StatProgression.spec.luau",
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

    sources = ",\n".join(
        f"{name} = {literal((ROOT / path).read_text(encoding='utf-8'))}"
        for name, path in FILES.items()
    )
    test = literal((ROOT / "tests/StatService.spec.luau").read_text(encoding="utf-8"))
    bundle = f"local Sources = {{\n{sources}\n}}\nlocal Run = assert(loadstring({test}))()\nprint(Run(Sources))\n"
    with tempfile.TemporaryDirectory(prefix="samurai-stat-tests-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
