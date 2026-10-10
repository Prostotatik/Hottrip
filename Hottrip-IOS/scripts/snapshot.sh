#!/usr/bin/env bash
# Собирает пакет и рендерит все экраны в PNG.
# Использование: scripts/snapshot.sh [--scale 2] [--only 04-tour] [--no-chrome] [--no-full]
# Вывод: _workspace/shared/snapshots/ (переопределить: OUT_DIR=/path scripts/snapshot.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/../_workspace/shared/snapshots}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
cd "$ROOT"

# В SDK macOS 27 @State объявлен макросом (SwiftUIMacros), а плагина этого макроса нет в Command Line
# Tools -> сборка падает. Если SDKROOT не задан и Xcode не установлен, берём самый новый MacOSX26.x.sdk.
if [[ -z "${SDKROOT:-}" ]] && [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
  FALLBACK_SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | grep -v 'MacOSX26.sdk$' | sort -V | tail -1 || true)"
  [[ -z "$FALLBACK_SDK" ]] && FALLBACK_SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | tail -1 || true)"
  if [[ -n "$FALLBACK_SDK" ]]; then
    export SDKROOT="$FALLBACK_SDK"
    echo "→ SDKROOT=$SDKROOT"
  fi
fi

echo "→ swift build"
# Ошибка сборки должна останавливать скрипт: иначе рендерится старый бинарь и снапшоты тихо устаревают.
if ! swift build --product HottripSnapshots > >(grep -Ev "ld: warning: search path" || true) 2>&1; then
  echo "✗ swift build failed" >&2; exit 1
fi
BIN="$(swift build --product HottripSnapshots --show-bin-path)/HottripSnapshots"
[[ -x "$BIN" ]] || { echo "Сборка не удалась"; exit 1; }

echo "→ render → $OUT_DIR"
"$BIN" "$OUT_DIR" --app-icon "$ROOT/App/Assets.xcassets/AppIcon.appiconset/app-icon-1024.png" "$@"
