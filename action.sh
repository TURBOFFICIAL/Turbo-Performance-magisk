#!/system/bin/sh
# Closes all background (third-party) apps.
# Optional $1 = package name to protect in addition to the user's exclude
# list (used when this script is invoked automatically because a
# "trigger app" was opened - see service.sh's trigger monitor loop).

MODDIR=${0%/*}
TRIGGER_APP="$1"
EXCLUDE_FILE="$MODDIR/exclude_apps.txt"

echo "====================================="
echo "   Turbo Performance - Background Cleaner"
echo "====================================="

CURRENT_LAUNCHER=$(cmd package resolve-activity -c android.intent.category.HOME 2>/dev/null | grep "packageName=" | cut -d'=' -f2)
ACTIVE_ROOT_PKG=$(pm list packages | grep -E "kernelsu|magisk|apatch|next" | cut -d':' -f2)

echo "[+] Launcher: ${CURRENT_LAUNCHER:-none}"
echo "[+] Root manager: ${ACTIVE_ROOT_PKG:-none}"
[ -n "$TRIGGER_APP" ] && echo "[+] Protecting trigger app: $TRIGGER_APP"

is_excluded() {
  pkg="$1"

  # Core safety exceptions - never editable by the user, required to keep
  # the screen usable and the root manager / this module functional.
  [ "$pkg" = "$CURRENT_LAUNCHER" ] && return 0
  [ "$pkg" = "$ACTIVE_ROOT_PKG" ] && return 0
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
