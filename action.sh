#!/system/bin/sh
# Closes all background (third-party) apps.
# Optional $1 = package name to protect in addition to the user's exclude
# list (used when this script is invoked automatically because a
# "trigger app" was opened - see service.sh's trigger monitor loop).

MODDIR=${0%/*}
TRIGGER_APP="$1"
EXCLUDE_FILE="$MODDIR/exclude_apps.txt"
LEARNED_MANAGER_FILE="$MODDIR/.known_root_manager"

echo "====================================="
echo "   Turbo Performance - Background Cleaner"
echo "====================================="

CURRENT_LAUNCHER=$(cmd package resolve-activity -c android.intent.category.HOME 2>/dev/null | grep "packageName=" | cut -d'=' -f2)

# Reliable, name-independent detection: whatever app is in the foreground
# RIGHT NOW is protected. When this script runs because the user tapped
# the button inside the WebUI, that foreground app IS the root manager -
# no need to guess its package name at all.
FOCUS_LINE=$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
CALLER_PKG=$(echo "$FOCUS_LINE" | sed -n 's#.*[{ ]u0 \([a-zA-Z0-9_.]*\)/.*#\1#p')

# Some root managers (e.g. KernelSU-Next) intentionally use a randomized/
# obfuscated package name to evade root-detection libraries, so matching
# by name ("*kernelsu*", "*magisk*"...) can never reliably find them. To
# handle this permanently, we "learn" the manager's real package name the
# moment we see it in the foreground (i.e. any time this script runs from
# a manual WebUI button tap) and remember it - so it stays protected even
# later, when this script is invoked automatically (watchdog/trigger) and
# the manager isn't in the foreground at that moment.
if [ -n "$CALLER_PKG" ]; then
  echo "$CALLER_PKG" > "$LEARNED_MANAGER_FILE" 2>/dev/null
fi
KNOWN_ROOT_PKG=$(cat "$LEARNED_MANAGER_FILE" 2>/dev/null)

# Fallback/secondary check by name pattern, in case the manager isn't
# obfuscated on some devices/forks. head -n1 avoids a multi-line match
# breaking the string comparison below.
ACTIVE_ROOT_PKG=$(pm list packages | grep -iE "kernelsu|magisk|apatch" | head -n1 | cut -d':' -f2)

echo "[+] Launcher: ${CURRENT_LAUNCHER:-none}"
echo "[+] Foreground caller (protected): ${CALLER_PKG:-none}"
echo "[+] Learned root manager (protected): ${KNOWN_ROOT_PKG:-none}"
echo "[+] Root manager (by name, fallback): ${ACTIVE_ROOT_PKG:-none}"
[ -n "$TRIGGER_APP" ] && echo "[+] Protecting trigger app: $TRIGGER_APP"

is_excluded() {
  pkg="$1"

  # Core safety exceptions - never editable by the user, required to keep
  # the screen usable and the root manager / this module functional.
  [ "$pkg" = "$CURRENT_LAUNCHER" ] && return 0
  [ -n "$CALLER_PKG" ] && [ "$pkg" = "$CALLER_PKG" ] && return 0
  [ -n "$KNOWN_ROOT_PKG" ] && [ "$pkg" = "$KNOWN_ROOT_PKG" ] && return 0
  [ -n "$ACTIVE_ROOT_PKG" ] && [ "$pkg" = "$ACTIVE_ROOT_PKG" ] && return 0
  [ -n "$TRIGGER_APP" ] && [ "$pkg" = "$TRIGGER_APP" ] && return 0

  case "$pkg" in
    *kernelsu*|*kernelsunext*|*magisk*|*apatch*|*tiann*|*topjohnwu*|*weishu*)
      return 0 ;;
    com.android.systemui|com.google.android.gms|com.google.android.gsf)
      return 0 ;;
  esac

  # User-defined exceptions (managed from the WebUI)
  if [ -f "$EXCLUDE_FILE" ] && grep -qx "$pkg" "$EXCLUDE_FILE" 2>/dev/null; then
    return 0
  fi

  return 1
}

STOPPED=0
for proc in $(pm list packages -3 | cut -d':' -f2); do
  if ! is_excluded "$proc"; then
    am force-stop "$proc" 2>/dev/null
    STOPPED=$((STOPPED + 1))
  fi
done

echo "[+] Stopped $STOPPED background app(s)."
echo "====================================="
exit 0
