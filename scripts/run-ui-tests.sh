#!/bin/bash
# Runs the simulator UI tests on the iPhone 15 Pro Max, one class at a time, and shows how far it has got.
#
#   scripts/run-ui-tests.sh                 every class
#   scripts/run-ui-tests.sh PortfolioUITests SearchUITests    only these classes
#   TOUR=1 scripts/run-ui-tests.sh ScreenTourUITests          the screenshot tour (see ScreenTourUITests.swift)
#
# Progress: each finished test prints "✓ [12/55] testName (23s)" or "✗ ...". The latest line is also kept in
# .uitest-logs/progress.txt. Results (and screenshots) land in .uitest-logs/<class>.xcresult.
set -uo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="iPhone 15 Pro Max"
LOGS=.uitest-logs
DERIVED=build/DerivedData
PER_TEST_SECONDS=90
MAX_TEST_SECONDS=180
PER_CLASS_SECONDS=1500

mkdir -p "$LOGS"
rm -f "$LOGS"/*.log "$LOGS"/progress.txt
rm -rf "$LOGS"/*.xcresult

XCODEBUILD_PID=""

# Without this the Mac stays slow after a run: simulators and Xcode's helpers keep gigabytes of memory.
cleanup() {
  if [[ -n "$XCODEBUILD_PID" ]] && kill -0 "$XCODEBUILD_PID" 2>/dev/null; then
    kill "$XCODEBUILD_PID" 2>/dev/null
    sleep 1
    kill -9 "$XCODEBUILD_PID" 2>/dev/null
  fi
  xcrun simctl shutdown all >/dev/null 2>&1
  osascript -e 'tell application "Simulator" to quit' >/dev/null 2>&1
  rm -f /tmp/hisaab-tour-enabled
}
trap cleanup EXIT
trap 'echo; echo "Stopped."; exit 130' INT TERM

UDID=$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z "$UDID" ]]; then
  echo "No simulator called $DEVICE_NAME is installed."
  exit 2
fi

if [[ -n "${TOUR:-}" ]]; then touch /tmp/hisaab-tour-enabled; fi

if [[ $# -gt 0 ]]; then
  CLASSES=("$@")
else
  CLASSES=()
  for file in tests/e2e/*UITests.swift; do CLASSES+=("$(basename "$file" .swift)"); done
fi

count_tests() { grep -c "func test" "tests/e2e/$1.swift"; }
TOTAL=0
for class in "${CLASSES[@]}"; do TOTAL=$((TOTAL + $(count_tests "$class"))); done

echo "Device: $DEVICE_NAME   Classes: ${#CLASSES[@]}   Tests: $TOTAL"
echo "Building..."
/private/tmp/xcodegen-bin/xcodegen/bin/xcodegen generate >/dev/null 2>&1 || xcodegen generate >/dev/null 2>&1
nice xcodebuild build-for-testing -project Hisaab.xcodeproj -scheme Hisaab \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO >"$LOGS/build.log" 2>&1
if [[ $? -ne 0 ]]; then
  echo "The build failed. See $LOGS/build.log"
  grep -E "error:" "$LOGS/build.log" | head -20
  exit 1
fi

xcrun simctl boot "$UDID" >/dev/null 2>&1

# Prints a line for every test that has finished since the last call. Every finished test is one line in the log, like:
#   Test Case '-[HisaabUITests.Class testName]' passed (12.3 seconds).
drain() {
  LINES=$(grep -E "^Test [Cc]ase .* (passed|failed|skipped)" "$LOG" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$LINES" -gt "$SEEN" ]]; then
    grep -E "^Test [Cc]ase .* (passed|failed|skipped)" "$LOG" | sed -n "$((SEEN + 1)),${LINES}p" > "$LOGS/new.txt"
    while IFS= read -r line; do
      name=$(echo "$line" | sed -E "s/^Test [Cc]ase '([^']*)'.*/\1/; s/^-\[[A-Za-z.]*[ .]//; s/[]()]//g")
      seconds=$(echo "$line" | sed -E 's/.*\(([0-9.]+) seconds\).*/\1/' | cut -d. -f1)
      DONE=$((DONE + 1))
      if echo "$line" | grep -q " passed"; then mark="✓"; PASSED=$((PASSED + 1))
      elif echo "$line" | grep -q " skipped"; then mark="–"; SKIPPED=$((SKIPPED + 1))
      else mark="✗"; FAILED=$((FAILED + 1)); FAILED_NAMES="$FAILED_NAMES $class.$name"; fi
      out="$mark [$DONE/$TOTAL] $name (${seconds}s)"
      echo "$out"
      echo "$out" > "$LOGS/progress.txt"
    done < "$LOGS/new.txt"
    SEEN=$LINES
    LAST_OUTPUT=$(date +%s)
  fi
}

DONE=0
PASSED=0
FAILED=0
SKIPPED=0
FAILED_NAMES=""
START=$(date +%s)

for class in "${CLASSES[@]}"; do
  LOG="$LOGS/$class.log"
  RESULT="$LOGS/$class.xcresult"
  echo
  echo "== $class ($(count_tests "$class") tests)"
  nice xcodebuild test-without-building -project Hisaab.xcodeproj -scheme Hisaab \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
    -only-testing:"HisaabUITests/$class" -resultBundlePath "$RESULT" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance "$PER_TEST_SECONDS" \
    -maximum-test-execution-time-allowance "$MAX_TEST_SECONDS" >"$LOG" 2>&1 &
  XCODEBUILD_PID=$!

  SEEN=0
  CLASS_START=$(date +%s)
  LAST_OUTPUT=$CLASS_START
  while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
    drain
    NOW=$(date +%s)
    if (( NOW - LAST_OUTPUT >= 60 )); then
      echo "… still running ($(( NOW - CLASS_START ))s in $class, $DONE/$TOTAL done)"
      LAST_OUTPUT=$NOW
    fi
    if (( NOW - CLASS_START > PER_CLASS_SECONDS )); then
      echo "✗ $class ran longer than $((PER_CLASS_SECONDS / 60)) minutes and was stopped"
      kill "$XCODEBUILD_PID" 2>/dev/null
      FAILED=$((FAILED + 1)); FAILED_NAMES="$FAILED_NAMES $class(timeout)"
      break
    fi
    sleep 2
  done

  # xcodebuild can hang after the last test while it writes the result bundle; give it a moment, then end it.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$XCODEBUILD_PID" 2>/dev/null || break
    [[ -d "$RESULT" ]] && break
    sleep 2
  done
  if kill -0 "$XCODEBUILD_PID" 2>/dev/null; then kill "$XCODEBUILD_PID" 2>/dev/null; fi
  wait "$XCODEBUILD_PID" 2>/dev/null
  XCODEBUILD_PID=""
  drain

  # A class that never reported (crash, build problem) counts as failed so it cannot hide.
  EXPECTED=$(count_tests "$class")
  if [[ "$SEEN" -lt "$EXPECTED" ]]; then
    MISSING=$((EXPECTED - SEEN))
    echo "✗ $class: $MISSING test(s) did not report. See $LOG"
    grep -E "error:|Testing failed|Failing tests" "$LOG" | head -8
    DONE=$((DONE + MISSING)); FAILED=$((FAILED + MISSING)); FAILED_NAMES="$FAILED_NAMES $class(missing:$MISSING)"
  fi
done

ELAPSED=$(( $(date +%s) - START ))
echo
echo "Finished in $((ELAPSED / 60))m $((ELAPSED % 60))s: $PASSED passed, $FAILED failed, $SKIPPED skipped, of $TOTAL."
if [[ "$FAILED" -gt 0 ]]; then
  echo "Failed:$FAILED_NAMES"
  exit 1
fi
