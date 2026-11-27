"""Run kick gameplay and validation checks against the production modules."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {
	"EgoConfig": "src/ReplicatedStorage/EgoConfig.luau",
    "Config": "src/ReplicatedStorage/KickConfig.luau",
    "Validate": "src/ReplicatedStorage/Validate.luau",
    "Movement": "src/ReplicatedStorage/CharacterShared.luau",
    "Facing": "src/ReplicatedStorage/Utils/ShouldFaceAim.luau",
    "Knockback": "src/ServerStorage/Services/KnockbackService.luau",
    "AssemblyMass": "src/ReplicatedStorage/Utils/GetAssemblyMass.luau",
    "Hit": "src/ServerStorage/Services/HitService.luau",
    "Kick": "src/ServerStorage/Services/KickService.luau",
    "Reaction": "src/ServerStorage/Services/EnemyReactionService.luau",
    "Input": "src/StarterPlayer/StarterCharacterScripts/InputController.luau",
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
    spec = (ROOT / "tests/Kick.spec.luau").read_text(encoding="utf-8")
    bundle = f"local Run = assert(loadstring({literal(spec)}))()\nprint(Run({{{sources}}}))\n"
    with tempfile.TemporaryDirectory(prefix="samurai-kick-tests-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
