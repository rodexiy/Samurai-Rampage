"""Run the production ragdoll recovery service with deterministic physics and timers."""
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

    service = (ROOT / "src/ServerStorage/Services/RagdollService.luau").read_text(encoding="utf-8")
    config = (ROOT / "src/ReplicatedStorage/RagdollConfig.luau").read_text(encoding="utf-8")
    spec = (ROOT / "tests/RagdollRecovery.spec.luau").read_text(encoding="utf-8")
    bundle = (
        f"local Run = assert(loadstring({literal(spec)}))()\n"
        f"local Config = assert(loadstring({literal(config)}))()\n"
        f"print(Run({literal(service)}, Config))\n"
    )
    controller = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Controllers/RagdollController.luau").read_text(encoding="utf-8")
    auto_rotate = (ROOT / "src/ReplicatedStorage/Utils/SetAutoRotate.luau").read_text(encoding="utf-8")
    controller_spec = (ROOT / "tests/RagdollController.spec.luau").read_text(encoding="utf-8")
    bundle += (
        f"local ControllerTest = assert(loadstring({literal(controller_spec)}))()\n"
        f"print(ControllerTest({literal(controller)}, {literal(auto_rotate)}))\n"
    )
    with tempfile.TemporaryDirectory(prefix="samurai-ragdoll-recovery-") as directory:
        script = Path(directory) / "run.luau"
        script.write_text(bundle, encoding="utf-8")
        subprocess.run([args.luau, str(script)], check=True)


if __name__ == "__main__":
    main()
