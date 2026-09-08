#!/system/bin/sh
# Shared ZRAM setup script.
# Called by service.sh at boot, and by the WebUI (via kernelsu exec)
# whenever the user changes ZRAM settings, so it applies live without reboot.

MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"
USER_CONFIG="$MODDIR/user_config.prop"

[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
[ -f "$USER_CONFIG" ] && . "$USER_CONFIG"

[ -z "$ZRAM_ALGO" ] && ZRAM_ALGO="lz4"
[ -z "$ZRAM_MODE" ] && ZRAM_MODE="auto"
[ -z "$ZRAM_PERCENT" ] && ZRAM_PERCENT=50

TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ -z "$TOTAL_RAM_KB" ] || [ "$TOTAL_RAM_KB" -le 0 ]; then
  echo "ERROR: could not read device RAM"
  exit 1
fi
TOTAL_RAM_BYTES=$((TOTAL_RAM_KB * 1024))

if [ "$ZRAM_MODE" = "manual" ] && [ -n "$ZRAM_MANUAL_MB" ] && [ "$ZRAM_MANUAL_MB" -gt 0 ] 2>/dev/null; then
  ZRAM_SIZE=$((ZRAM_MANUAL_MB * 1024 * 1024))
else
  ZRAM_MODE="auto"
  ZRAM_SIZE=$((TOTAL_RAM_BYTES * ZRAM_PERCENT / 100))
fi

# Safety cap: never allow ZRAM bigger than total device RAM (protects against
# a bad manual value bricking swap performance / causing instability)
if [ "$ZRAM_SIZE" -gt "$TOTAL_RAM_BYTES" ]; then
  ZRAM_SIZE=$TOTAL_RAM_BYTES
  echo "WARNING: requested ZRAM size exceeded total RAM, capped to ${ZRAM_SIZE} bytes"
fi

if [ ! -e /dev/block/zram0 ]; then
  echo "ERROR: zram0 not found on this kernel"
  exit 1
fi

swapoff /dev/block/zram0 2>/dev/null
echo 1 > /sys/block/zram0/reset 2>/dev/null
echo "${ZRAM_ALGO}" > /sys/block/zram0/comp_algorithm 2>/dev/null
echo "${ZRAM_SIZE}" > /sys/block/zram0/disksize 2>/dev/null

if [ "$?" -eq 0 ]; then
  mkswap /dev/block/zram0 > /dev/null 2>&1
  swapon /dev/block/zram0 > /dev/null 2>&1
  echo "OK: ZRAM active - mode=${ZRAM_MODE}, algo=${ZRAM_ALGO}, size=${ZRAM_SIZE} bytes"
  exit 0
else
  echo "ERROR: failed to set zram0 disksize"
  exit 1
fi
