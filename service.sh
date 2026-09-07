#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"
LOCK_FILE="/dev/shm/turbo_sysctl.lock"

# Prevent duplicate loops
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

if [ -z "$ZRAM_ALGO" ]; then
  exit 1
fi

[ -z "$ZRAM_PERCENT" ] && ZRAM_PERCENT=50

# ===== Dynamic ZRAM Calculation =====
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ -z "$TOTAL_RAM_KB" ] || [ "$TOTAL_RAM_KB" -le 0 ]; then
  exit 1
fi
TOTAL_RAM_BYTES=$((TOTAL_RAM_KB * 1024))
ZRAM_SIZE=$((TOTAL_RAM_BYTES * ZRAM_PERCENT / 100))

# ===== Setup ZRAM =====
if [ ! -e /dev/block/zram0 ]; then
  :
else
  swapoff /dev/block/zram0 2>/dev/null
  echo 1 > /sys/block/zram0/reset 2>/dev/null
  echo "${ZRAM_ALGO}" > /sys/block/zram0/comp_algorithm 2>/dev/null
  echo "${ZRAM_SIZE}" > /sys/block/zram0/disksize 2>/dev/null
  if [ "$?" -eq 0 ]; then
    mkswap /dev/block/zram0 > /dev/null 2>&1
    swapon /dev/block/zram0 > /dev/null 2>&1
  fi
fi

# ===== Apply sysctl immediately =====
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

# ===== Enforce sysctl every 30 seconds (faster recovery from overrides) =====
(
  while true; do
    apply_sysctl
    sleep 30
  done
) &

# ===== WebUI stats update loop - 3 second interval (balanced) =====
(
  while true; do
    MEMINFO=$(cat /proc/meminfo)
    MEM_TOTAL=$(echo "$MEMINFO" | awk '/MemTotal/ {print $2}')
    MEM_AVAIL=$(echo "$MEMINFO" | awk '/MemAvailable/ {print $2}')
    SWAP_TOTAL=$(echo "$MEMINFO" | awk '/SwapTotal/ {print $2}')
    SWAP_FREE=$(echo "$MEMINFO" | awk '/SwapFree/ {print $2}')

    SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    DIRTY_RATIO=$(cat /proc/sys/vm/dirty_ratio 2>/dev/null || echo "20")
    DIRTY_BG_RATIO=$(cat /proc/sys/vm/dirty_background_ratio 2>/dev/null || echo "5")
    VFS_PRESSURE=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "100")

    ZRAM_CUR_ALGO="$ZRAM_ALGO"
    if [ -f /sys/block/zram0/comp_algorithm ]; then
      ZRAM_CUR_ALGO=$(cat /sys/block/zram0/comp_algorithm | grep -o '\[.*\]' | tr -d '[]')
      [ -z "$ZRAM_CUR_ALGO" ] && ZRAM_CUR_ALGO=$(cat /sys/block/zram0/comp_algorithm | awk '{print $1}')
    fi

    CPU_TEMP=$(cat /sys/class/thermal/thermal_zone22/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    CPU_FREQ=$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq 2>/dev/null || cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null || echo "0")
    GPU_FREQ=$(cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null || cat /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq 2>/dev/null || echo "0")

    BAT_LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "0")
    BAT_TEMP=$(cat /sys/class/power_supply/battery/temp 2>/dev/null || echo "0")
    BAT_NOW=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null || echo "0")
    BAT_CHARGE_FULL=$(cat /sys/class/power_supply/battery/charge_full 2>/dev/null || cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || echo "0")
    BAT_DESIGN_FULL=$(cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || echo "5000000")

    cat > "$MODDIR/webroot/assets/stats.json" <<EOF
{
  "memTotal": $MEM_TOTAL,
  "memAvail": $MEM_AVAIL,
  "swapTotal": $SWAP_TOTAL,
  "swapFree": $SWAP_FREE,
  "swappiness": $SWAPPINESS,
  "dirtyRatio": $DIRTY_RATIO,
  "dirtyBgRatio": $DIRTY_BG_RATIO,
  "vfsPressure": $VFS_PRESSURE,
  "zramAlgo": "$ZRAM_CUR_ALGO",
  "cpuTemp": "$CPU_TEMP",
  "cpuFreq": "$CPU_FREQ",
  "gpuFreq": "$GPU_FREQ",
  "batLevel": "$BAT_LEVEL",
  "batTemp": "$BAT_TEMP",
  "batNow": "$BAT_NOW",
  "batChargeFull": "$BAT_CHARGE_FULL",
  "batDesignFull": "$BAT_DESIGN_FULL"
}
EOF

    sleep 3
  done
) &

exit 0
