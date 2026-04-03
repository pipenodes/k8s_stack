"""Substitui workload-* por {env}-workload-* em YAMLs, excluindo charts/templates."""
from __future__ import annotations
import re
from pathlib import Path

TIERS = ("workload-vault", "workload-obs", "workload-common")

def patch_text(text: str, env_prefix: str) -> str:
    for tier in TIERS:
        new = f"{env_prefix}-{tier}"
        pat = rf"(?<!{re.escape(env_prefix)}-){re.escape(tier)}(?![a-z0-9-])"
        text = re.sub(pat, new, text)
    return text

def main() -> None:
    root = Path(__file__).resolve().parent.parent
    for env_name, prefix in (("development", "development"), ("production", "production")):
        base = root / env_name
        if not base.is_dir():
            continue
        for path in base.rglob("*.yaml"):
            if "charts" in path.parts or "templates" in path.parts:
                continue
            raw = path.read_text(encoding="utf-8")
            new = patch_text(raw, prefix)
            if new != raw:
                path.write_text(new, encoding="utf-8")
                print("updated", path.relative_to(root))

if __name__ == "__main__":
    main()
