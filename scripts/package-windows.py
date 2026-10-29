#!/usr/bin/env python3
"""Package tracked sources (never local .env, caches or build artifacts)."""
import hashlib
import pathlib
import subprocess
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
output = root / "dist"
output.mkdir(exist_ok=True)
archive = output / "deadlock-owl-windows.zip"
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).split(b"\0")
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
    for raw in files:
        if not raw:
            continue
        name = raw.decode("utf-8")
        path = pathlib.PurePosixPath(name)
        if any(part in {".git", "node_modules", "target", ".cache"} for part in path.parts):
            continue
        if path.name.startswith(".env") and path.name != ".env.example":
            continue
        bundle.write(root / name, f"deadlock-owl/{name}")
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive.name}\n", encoding="ascii")
print(archive)
