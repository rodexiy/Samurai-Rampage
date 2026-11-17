"""Run the production combat service against deterministic lifecycle regressions."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


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

    source = (ROOT / "src/ServerStorage/Services/InCombatService.luau").read_text(encoding="utf-8")
    test = (ROOT / "tests/InCombatService.spec.luau").read_text(encoding="utf-8")
    bundle = f"local Run = assert(loadstring({literal(test)}))()\nprint(Run({literal(source)}))\n"
    with tempfile.TemporaryDirectory(prefix="samurai-combat-tests-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
