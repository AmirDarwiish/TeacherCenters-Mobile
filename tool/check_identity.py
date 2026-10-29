"""Check the approved Rewaq identity before building any app artifact."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "docs/identity-baseline.json").read_text())
errors = []
for name, sha in manifest["assets"].items():
    path = root / name
    if not path.is_file():
        errors.append(f"Missing approved identity asset: {name}")
        continue
    data = path.read_bytes()
    actual = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
    if actual != sha:
        errors.append(f"Identity asset changed without updating the approved baseline: {name}")
for name, required in manifest["required"].items():
    text = (root / name).read_text()
    for value in required:
        if value not in text:
            errors.append(f"Missing Rewaq identity value {value!r} in {name}")
for name in ("lib", "android/app/src/main/AndroidManifest.xml", "ios/Runner/Info.plist", "web/manifest.json"):
    target = root / name
    paths = target.rglob("*.dart") if target.is_dir() else [target]
    for path in paths:
        text = path.read_text()
        if "سنترك" in text or "Tajawal" in text:
            errors.append(f"Retired display identity in {path.relative_to(root)}")
if errors:
    raise SystemExit("\n".join(errors))
print("Rewaq identity baseline verified.")
