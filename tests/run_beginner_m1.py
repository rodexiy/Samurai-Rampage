"""Exercise Beginner katana movement and combo timing with a simulated clock."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "Beginner": "src/ReplicatedStorage/Index/Stances/Beginner.luau",
    "Validate": "src/ReplicatedStorage/Validate.luau",
    "Movement": "src/ReplicatedStorage/CharacterShared.luau",
    "Acceleration": "src/StarterPlayer/StarterCharacterScripts/Acceleration.client.luau",
    "Debounce": "src/ServerStorage/Services/DebounceService.luau",
    "WeaponService": "src/ServerStorage/Services/WeaponService/init.luau",
    "Weapons": "src/ServerStorage/Services/WeaponService/Weapons/init.luau",
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

    sources = ",\n".join(f"{name} = {literal((ROOT / path).read_text(encoding='utf-8'))}" for name, path in FILES.items())
    test = literal((ROOT / "tests/BeginnerM1Flow.spec.luau").read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="samurai-beginner-m1-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(f"local Run = assert(loadstring({test}))()\nprint(Run({{{sources}}}))\n", encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
