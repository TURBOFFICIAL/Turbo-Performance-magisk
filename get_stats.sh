#!/system/bin/sh
# Called on-demand by the WebUI (via kernelsu exec) only while it's open.
# Prints RAM/ZRAM stats as JSON to stdout. No background loop, no idle
# overhead, no config reading - just the numbers the dashboard needs.

eval "$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{gsub(":","");print $1"="$2}' /proc/meminfo)"

cat <<EOF2
{
  "memTotal": $MemTotal,
  "memAvail": $MemAvailable,
  "swapTotal": $SwapTotal,
  "swapFree": $SwapFree
}
EOF2
