#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"
LOCK_FILE="/dev/shm/turbo_sysctl.lock"

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
      FOCUS_LINE=$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
      FOCUS_PKG=$(echo "$FOCUS_LINE" | sed -n 's#.*[{ ]u0 \([a-zA-Z0-9_.]*\)/.*#\1#p')

      if [ -n "$FOCUS_PKG" ] && [ "$FOCUS_PKG" != "$LAST_FOCUS_PKG" ]; then
        if grep -qx "$FOCUS_PKG" "$MODDIR/trigger_apps.txt" 2>/dev/null; then
          sh "$MODDIR/action.sh" "$FOCUS_PKG"
        fi
        LAST_FOCUS_PKG="$FOCUS_PKG"
      fi
    fi
    sleep 4
  done
) &

# ===== WebUI stats loop (RAM + ZRAM only, 3 second interval) =====
(
  while true; do
    MEMINFO=$(cat /proc/meminfo)
    MEM_TOTAL=$(echo "$MEMINFO" | awk '/MemTotal/ {print $2}')
    MEM_AVAIL=$(echo "$MEMINFO" | awk '/MemAvailable/ {print $2}')
    SWAP_TOTAL=$(echo "$MEMINFO" | awk '/SwapTotal/ {print $2}')
    SWAP_FREE=$(echo "$MEMINFO" | awk '/SwapFree/ {print $2}')

    ZRAM_MODE_CUR="auto"
    ZRAM_MANUAL_MB_CUR="0"
    TRIGGER_ENABLED_CUR="false"
    [ -f "$MODDIR/user_config.prop" ] && . "$MODDIR/user_config.prop" \
      && ZRAM_MODE_CUR="$ZRAM_MODE" && ZRAM_MANUAL_MB_CUR="$ZRAM_MANUAL_MB" && TRIGGER_ENABLED_CUR="$TRIGGER_ENABLED"

    cat > "$MODDIR/webroot/assets/stats.json" <<EOF
{
  "memTotal": $MEM_TOTAL,
  "memAvail": $MEM_AVAIL,
  "swapTotal": $SWAP_TOTAL,
  "swapFree": $SWAP_FREE,
  "zramMode": "$ZRAM_MODE_CUR",
  "zramManualMb": $ZRAM_MANUAL_MB_CUR,
  "triggerEnabled": $TRIGGER_ENABLED_CUR
}
EOF
    sleep 3
  done
) &

exit 0
