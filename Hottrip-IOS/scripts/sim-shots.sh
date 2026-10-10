#!/usr/bin/env bash
# Скриншоты и видео приложения с настоящего симулятора iOS.
#
#   scripts/sim-shots.sh                       # собрать, поставить, снять все кадры каталога
#   scripts/sim-shots.sh --only 04             # только кадры, в имени которых есть «04»
#   scripts/sim-shots.sh --video tour/operatorCoral   # видео 7 с после запуска экрана + кадры ffmpeg
#   scripts/sim-shots.sh --ui PaymentSuccess   # видео XCUITest-сценария (тапы) + кадры; --ui all — все
#   scripts/sim-shots.sh --list                # список кадров и сценариев
#
# Опции: --no-build (не пересобирать), --fps N (кадров в секунду при извлечении, по умолчанию 10),
#        --seconds N (длина --video, по умолчанию 7), --delay N (пауза перед скриншотом, по умолчанию 3).
# Окружение: SIM_UDID (по умолчанию iPhone 18 Pro из брифа), OUT_DIR (по умолчанию _workspace/shared/sim-shots).
# Реестр кадров читается из Sources/HottripUI/Navigation/DemoLaunch.swift (один источник правды).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${SIM_UDID:-71595551-8B3E-4C78-BC29-9ED88A051492}"
OUT_DIR="${OUT_DIR:-$ROOT/../_workspace/shared/sim-shots}"
DERIVED="$ROOT/.build-xcode"
BUNDLE_ID="uz.hottrip.demo"
UI_CLASS="HottripUITests/HottripUITests"

BUILD=1; ONLY=""; VIDEO=""; UI=""; FPS=10; SECONDS_REC=7; DELAY=3; LIST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) BUILD=0 ;;
    --only) ONLY="$2"; shift ;;
    --video) VIDEO="$2"; shift ;;
    --ui) UI="$2"; shift ;;
    --fps) FPS="$2"; shift ;;
    --seconds) SECONDS_REC="$2"; shift ;;
    --delay) DELAY="$2"; shift ;;
    --list) LIST=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "неизвестная опция: $1" >&2; exit 1 ;;
  esac
  shift
done

# Реестр: строки «screen state shot».
ENTRIES="$(sed -nE 's/.*\.init\(screen: "([^"]+)", state: "([^"]+)", shot: "([^"]+)"\).*/\1 \2 \3/p' \
  "$ROOT/Sources/HottripUI/Navigation/DemoLaunch.swift")"
SCENARIOS="$(sed -nE 's/^[[:space:]]*func test([A-Za-z0-9]+)\(\).*/\1/p' "$ROOT/HottripUITests/HottripUITests.swift")"

if [[ $LIST == 1 ]]; then
  echo "Кадры (-demoScreen / -demoState → файл):"; echo "$ENTRIES" | awk '{printf "  %-10s %-16s %s.png\n", $1, $2, $3}'
  echo "UI-сценарии (--ui):"; echo "$SCENARIOS" | sed 's/^/  /'
  exit 0
fi

mkdir -p "$OUT_DIR" "$DERIVED"; OUT_DIR="$(cd "$OUT_DIR" && pwd)"

# Симулятор: загрузить при необходимости, зафиксировать строку состояния (9:41, полный заряд).
if ! xcrun simctl list devices | grep "$UDID" | grep -q Booted; then
  echo "→ boot $UDID"; xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b >/dev/null
fi
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100 >/dev/null

if [[ $BUILD == 1 ]]; then
  echo "→ xcodebuild build-for-testing (derivedData: .build-xcode)"
  if ! xcodebuild -project "$ROOT/Hottrip.xcodeproj" -scheme Hottrip -configuration Debug \
      -destination "id=$UDID" -derivedDataPath "$DERIVED" build-for-testing > "$DERIVED/build.log" 2>&1; then
    grep -E "error:" "$DERIVED/build.log" | head -20 >&2; echo "✗ сборка не удалась, лог: $DERIVED/build.log" >&2; exit 1
  fi
fi
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Hottrip.app"
[[ -d "$APP" ]] || { echo "нет $APP — запустите без --no-build" >&2; exit 1; }
xcrun simctl install "$UDID" "$APP"

launch() { # screen state
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -demoScreen "$1" -demoState "$2" >/dev/null
}

REC_PID=""
# Прерванный скрипт не должен оставлять запись висеть (иначе следующая: «Host recording is already in progress»).
trap 'if [[ -n "$REC_PID" ]]; then kill -INT "$REC_PID" 2>/dev/null || true; fi' EXIT
record_start() { # file
  rm -f "$1"
  REC_FILE="$1"
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$1" > "$DERIVED/record.log" 2>&1 &
  REC_PID=$!
  # recordVideo стартует не мгновенно: ждём «Recording started».
  for _ in $(seq 1 50); do grep -q "Recording started" "$DERIVED/record.log" 2>/dev/null && break; sleep 0.1; done
}
record_stop() {
  kill -INT "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true
  REC_PID=""
  for _ in $(seq 1 50); do [[ -s "$REC_FILE" ]] && break; sleep 0.1; done
  [[ -s "$REC_FILE" ]] || { echo "✗ видео не записалось: $(cat "$DERIVED/record.log")" >&2; return 1; }
}
frames() { # movie dir
  rm -rf "$2"; mkdir -p "$2"
  # Половина разрешения (603 px по ширине): кадров много, для проверки анимаций этого достаточно.
  ffmpeg -loglevel error -i "$1" -vf "fps=$FPS,scale=603:-2" "$2/%04d.png"
  echo "  $(ls "$2" | wc -l | tr -d ' ') кадров → $2"
}

if [[ -n "$VIDEO" ]]; then
  screen="${VIDEO%%/*}"; state="default"; [[ "$VIDEO" == */* ]] && state="${VIDEO#*/}"
  shot="$(echo "$ENTRIES" | awk -v s="$screen" -v t="$state" '$1==s && $2==t {print $3}')"
  [[ -n "$shot" ]] || { echo "нет кадра $screen/$state (см. --list)" >&2; exit 1; }
  mkdir -p "$OUT_DIR/video"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  MOV="$OUT_DIR/video/$shot.mov"
  echo "→ видео $shot (${SECONDS_REC} с)"
  record_start "$MOV"; launch "$screen" "$state"; sleep "$SECONDS_REC"; record_stop
  frames "$MOV" "$OUT_DIR/video/$shot"
  exit 0
fi

if [[ -n "$UI" ]]; then
  [[ "$UI" == all ]] && list="$SCENARIOS" || list="$UI"
  mkdir -p "$OUT_DIR/video"
  FAILED=""
  for sc in $list; do
    name="ui-$(echo "$sc" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')"
    MOV="$OUT_DIR/video/$name.mov"
    echo "→ UI-сценарий test$sc → $name"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    record_start "$MOV"
    status=0
    RESULT="$DERIVED/results/$sc.xcresult"; rm -rf "$RESULT" # только последний прогон сценария
    xcodebuild -project "$ROOT/Hottrip.xcodeproj" -scheme Hottrip -destination "id=$UDID" \
      -derivedDataPath "$DERIVED" test-without-building -only-testing:"$UI_CLASS/test$sc" \
      -collect-test-diagnostics never -resultBundlePath "$RESULT" \
      > "$DERIVED/ui-test.log" 2>&1 || status=$?
    record_stop
    if [[ $status != 0 ]]; then
      grep -E "error|failed" "$DERIVED/ui-test.log" | head -10 >&2; echo "✗ test$sc упал (лог: $DERIVED/ui-test.log); видео сохранено" >&2
      FAILED="$FAILED $sc"
    fi
    frames "$MOV" "$OUT_DIR/video/$name"
  done
  [[ -z "$FAILED" ]] || { echo "✗ упали сценарии:$FAILED" >&2; exit 1; }
  exit 0
fi

echo "→ скриншоты → $OUT_DIR"
echo "$ENTRIES" | while read -r screen state shot; do
  [[ -n "$ONLY" && "$shot" != *"$ONLY"* ]] && continue
  launch "$screen" "$state"
  wait_s="$DELAY"
  [[ "$state" == *Toast ]] && wait_s=1.5 # тост сам уходит через ~3 с — снимаем, пока он на экране
  sleep "$wait_s"
  xcrun simctl io "$UDID" screenshot --type png "$OUT_DIR/$shot.png" >/dev/null 2>&1
  echo "  $shot.png"
done
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
