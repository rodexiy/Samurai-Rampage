"""Run the real intro, hit and damage services against transition regressions."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "Intro": "src/ServerStorage/Services/IntroCutsceneService.luau",
    "Hit": "src/ServerStorage/Services/HitService.luau",
    "Damage": "src/ServerStorage/Services/DamageService.luau",
    "Client": "src/StarterPlayer/StarterPlayerScripts/Controllers/TsunamiCutsceneController.luau",
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
    test = (ROOT / "tests/IntroHeavyParry.spec.luau").read_text(encoding="utf-8")
    bundle = f"local Run = assert(loadstring({literal(test)}))()\nprint(Run({{{sources}}}))\n"
    with tempfile.TemporaryDirectory(prefix="samurai-intro-parry-tests-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
