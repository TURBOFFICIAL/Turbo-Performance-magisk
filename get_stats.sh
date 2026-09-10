#!/system/bin/sh
# Called on-demand by the WebUI (via kernelsu exec) only while it's open.
# Prints stats as JSON to stdout. No background loop, no idle overhead.

MODDIR=${0%/*}

eval "$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{gsub(":","");print $1"="$2}' /proc/meminfo)"

ZRAM_MODE_CUR="auto"
ZRAM_MANUAL_MB_CUR="0"
TRIGGER_ENABLED_CUR="false"
if [ -f "$MODDIR/user_config.prop" ]; then
  . "$MODDIR/user_config.prop"
  ZRAM_MODE_CUR="$ZRAM_MODE"
  ZRAM_MANUAL_MB_CUR="$ZRAM_MANUAL_MB"
  TRIGGER_ENABLED_CUR="$TRIGGER_ENABLED"
fi

cat <<EOF
{
  "memTotal": $MemTotal,
  "memAvail": $MemAvailable,
  "swapTotal": $SwapTotal,
  "swapFree": $SwapFree,
  "zramMode": "$ZRAM_MODE_CUR",
  "zramManualMb": $ZRAM_MANUAL_MB_CUR,
  "triggerEnabled": $TRIGGER_ENABLED_CUR
}
EOF
