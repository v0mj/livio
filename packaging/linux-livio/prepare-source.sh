#!/usr/bin/env bash
set -euo pipefail

destination="${1:?destination directory is required}"
source_repo="${LIVIO_KERNEL_SOURCE_REPO:-https://gitlab.archlinux.org/archlinux/packaging/packages/linux-zen.git}"
source_ref="${LIVIO_KERNEL_SOURCE_REF:-}"

rm -rf "$destination"
mkdir -p "$(dirname "$destination")"

clone_args=(--depth 1)
if [[ -n "$source_ref" ]]; then
    clone_args+=(--branch "$source_ref")
fi

git clone "${clone_args[@]}" "$source_repo" "$destination"

python_cmd="${PYTHON:-}"
if [[ -z "$python_cmd" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        python_cmd="python3"
    else
        python_cmd="python"
    fi
fi

"$python_cmd" - "$destination/PKGBUILD" <<'PY'
from pathlib import Path
import re
import sys

pkgbuild = Path(sys.argv[1])
text = pkgbuild.read_text()

text = text.replace("pkgbase=linux-zen", "pkgbase=linux-livio")
text = text.replace("pkgdesc='Linux ZEN'", "pkgdesc='Livio gaming kernel based on Linux ZEN'")
text = text.replace("export KBUILD_BUILD_HOST=archlinux", "export KBUILD_BUILD_HOST=livio")

text = re.sub(
    r"\n  # htmldocs\n  graphviz\n  imagemagick\n  python-sphinx\n  python-yaml\n  texlive-latexextra\n",
    "\n",
    text,
)

text = text.replace(
    "  cp ../config.$CARCH .config\n  make olddefconfig\n",
    """  cp ../config.$CARCH .config

  echo "Applying Livio gaming config..."
  scripts/config --enable PREEMPT_DYNAMIC || true
  scripts/config --enable HZ_1000 || true
  scripts/config --set-val HZ 1000 || true
  scripts/config --enable CC_OPTIMIZE_FOR_PERFORMANCE || true

  make olddefconfig
""",
)

text = text.replace("  make htmldocs SPHINXOPTS=-QT\n", "")
text = text.replace('  "$pkgbase-docs"\n', "")

pkgbuild.write_text(text)
PY

cat > "$destination/LIVIO-KERNEL.txt" <<'EOF'
Livio kernel package source

This package is generated from Arch Linux's linux-zen package recipe and
renamed to linux-livio. The intent is a stable gaming-oriented kernel path:
use the maintained Zen patchset, apply conservative latency-oriented config
defaults, and keep linux-lts installed as the recovery kernel.
EOF
