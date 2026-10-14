#!/usr/bin/env bash
# Installs the APK on the running Android emulator exactly as a phone would, then
# launches it and reports whether it stays alive. Runs inside the emulator job of
# .github/workflows/build_apk.yml; the report is written to install-report.txt and
# published as an annotation.
#
# Usage: bash tools/android/emulator_install_check.sh <apk>
set -u
APK="${1:?usage: emulator_install_check.sh <apk>}"
PACKAGE="app.hady.platform"
REPORT="install-report.txt"
: > "$REPORT"

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

log "device: $(adb shell getprop ro.product.model | tr -d '\r') / Android $(adb shell getprop ro.build.version.release | tr -d '\r') (API $(adb shell getprop ro.build.version.sdk | tr -d '\r')), ABI $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
log "apk: $APK ($(stat -c %s "$APK") bytes)"

install_output="$(adb install -r "$APK" 2>&1)"
install_status=$?
log "adb install -> exit $install_status"
log "$install_output"
if [ $install_status -ne 0 ] || ! printf '%s' "$install_output" | grep -q "Success"; then
  log "RESULT: INSTALL FAILED"
  adb logcat -d 2>/dev/null | grep -iE "PackageManager|PackageParser|ParsingPackage|INSTALL_" | tail -40 | tee -a "$REPORT"
  exit 1
fi
log "installed: $(adb shell pm list packages "$PACKAGE" | tr -d '\r')"
log "launcher: $(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PACKAGE" | tr -d '\r' | tail -1)"

adb logcat -c
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15
pid="$(adb shell pidof "$PACKAGE" | tr -d '\r')"
if [ -z "$pid" ]; then
  log "RESULT: INSTALLED BUT THE APP IS NOT RUNNING AFTER LAUNCH"
  adb logcat -d 2>/dev/null | grep -E "AndroidRuntime|FATAL|flutter|$PACKAGE" | tail -60 | tee -a "$REPORT"
  exit 1
fi
log "running: pid $pid"
log "foreground: $(adb shell dumpsys activity activities | grep -m1 -E 'mResumedActivity|topResumedActivity' | tr -d '\r')"
if adb logcat -d 2>/dev/null | grep -q "FATAL EXCEPTION"; then
  log "WARNING: a fatal exception was logged:"
  adb logcat -d 2>/dev/null | grep -A12 "FATAL EXCEPTION" | head -40 | tee -a "$REPORT"
fi
log "RESULT: INSTALLED AND RUNNING"
