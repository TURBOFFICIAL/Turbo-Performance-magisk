#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"
LOCK_FILE="/data/local/tmp/turbo_sysctl.lock"

# Prevent duplicate loops if this script runs more than once
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE")
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
fi
echo "$$" > "$LOCK_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
  exit 1
fi
. "$CONFIG_FILE"

# ===== ZRAM setup (shared logic with the WebUI live-apply button) =====
sh "$MODDIR/apply_zram.sh" >/dev/null 2>&1

# ===== Apply VM memory parameters immediately =====
apply_sysctl() {
  sysctl -w vm.swappiness=60 vm.dirty_ratio=20 vm.dirty_background_ratio=5 vm.vfs_cache_pressure=100 2>/dev/null
  echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null
}
apply_sysctl

# ===== Wait for boot completion =====
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done
while ! pm list packages >/dev/null 2>&1; do
  sleep 2
done

MODDIR="/data/adb/modules/Turbo-Performance"
mkdir -p "$MODDIR/webroot/assets"

# Ensure default setting files exist so the WebUI/action.sh never fail
# reading them on a fresh install (first boot after installing the module)
[ -f "$MODDIR/exclude_apps.txt" ] || touch "$MODDIR/exclude_apps.txt"
[ -f "$MODDIR/trigger_apps.txt" ] || touch "$MODDIR/trigger_apps.txt"
[ -f "$MODDIR/user_config.prop" ] || cat > "$MODDIR/user_config.prop" <<EOF
ZRAM_MODE=auto
ZRAM_PERCENT=50
ZRAM_MANUAL_MB=0
TRIGGER_ENABLED=false
EOF

# ===== Background loop: enforce VM parameters every 30 seconds =====
# Some ROMs/kernel services override these values after boot, so we
# periodically re-apply them to keep them stable.
(
  while true; do
    apply_sysctl
    sleep 30
  done
) &

# ===== Optional feature: auto-close background apps when a "trigger app"
# is opened. Disabled by default (TRIGGER_ENABLED=false in user_config.prop,
# editable from the WebUI). Re-reads settings every cycle so toggling the
# feature or editing the trigger app list from the WebUI takes effect
# immediately, with no reboot needed. =====
(
  LAST_FOCUS_PKG=""
  while true; do
    TRIGGER_ENABLED="false"
    [ -f "$MODDIR/user_config.prop" ] && . "$MODDIR/user_config.prop"

    if [ "$TRIGGER_ENABLED" = "true" ] && [ -s "$MODDIR/trigger_apps.txt" ]; then
      # dumpsys window is a relatively heavy call - only run it while the
      # feature is actually enabled, never on every idle cycle.
      FOCUS_LINE=$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
      FOCUS_PKG=$(echo "$FOCUS_LINE" | sed -n 's#.*[{ ]u0 \([a-zA-Z0-9_.]*\)/.*#\1#p')

      if [ -n "$FOCUS_PKG" ] && [ "$FOCUS_PKG" != "$LAST_FOCUS_PKG" ]; then
        if grep -qx "$FOCUS_PKG" "$MODDIR/trigger_apps.txt" 2>/dev/null; then
          sh "$MODDIR/action.sh" "$FOCUS_PKG"
        fi
        LAST_FOCUS_PKG="$FOCUS_PKG"
      fi
      sleep 4
    else
      # Feature disabled (default state) - just re-check the config flag
      # every 30s, with zero dumpsys/grep overhead in between.
      sleep 30
    fi
  done
) &

# ملحوظة: لوب كتابة stats.json اتشال من هنا نهائياً. دلوقتي الـ WebUI نفسه
# بينادي get_stats.sh مباشرة وقت ما يكون مفتوح بس (شوف monitor.js)،
# فمفيش أي عملية بتشتغل في الخلفية لحساب الـ RAM/ZRAM لما تقفل الـ WebUI.

exit 0
