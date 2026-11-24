"""Run the intro lesson state machine with deterministic input and timing."""
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
    source = (ROOT / "src/ServerStorage/Services/IntroCombatTutorialService.luau").read_text(encoding="utf-8")
    damage = (ROOT / "src/ServerStorage/Services/DamageService.luau").read_text(encoding="utf-8")
    validate = (ROOT / "src/ReplicatedStorage/Validate.luau").read_text(encoding="utf-8")
    test = (ROOT / "tests/IntroCombatTutorial.spec.luau").read_text(encoding="utf-8")
    bundle = f"local Run = assert(loadstring({literal(test)}))()\nprint(Run({literal(source)}, {literal(damage)}, {literal(validate)}))\n"
    pause = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Controllers/IntroScenePauseController.luau").read_text(encoding="utf-8")
    pause_test = (ROOT / "tests/IntroScenePause.spec.luau").read_text(encoding="utf-8")
    bundle += f"local Pause = assert(loadstring({literal(pause_test)}))()\nprint(Pause({literal(pause)}))\n"
    sword = (ROOT / "src/ServerStorage/Services/WeaponService/Weapons/init.luau").read_text(encoding="utf-8")
    sword_test = (ROOT / "tests/IntroSwordHit.spec.luau").read_text(encoding="utf-8")
    bundle += f"local Sword = assert(loadstring({literal(sword_test)}))()\nprint(Sword({literal(sword)}))\n"
    with tempfile.TemporaryDirectory(prefix="samurai-intro-lessons-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
