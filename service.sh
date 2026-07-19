#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"

# ===== سطر تشخيص: يثبت إن السكريبت فعلاً اتنفذ ووقت إيه =====
echo "service.sh executed at: $(date)" >> /data/local/tmp/turbo_debug_log.txt

if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.prop not found! Exiting." >> /data/local/tmp/turbo_debug_log.txt
  exit 1
fi

. "$CONFIG_FILE"

if [ -z "$ZRAM_ALGO" ]; then
  echo "ZRAM_ALGO not set! Exiting." >> /data/local/tmp/turbo_debug_log.txt
  exit 1
fi

# نسبة افتراضية لو المستخدم مسيبهاش في config.prop
[ -z "$ZRAM_PERCENT" ] && ZRAM_PERCENT=50

# ===== حساب حجم الـ ZRAM ديناميكياً حسب رام الجهاز الفعلي =====
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ -z "$TOTAL_RAM_KB" ] || [ "$TOTAL_RAM_KB" -le 0 ]; then
  echo "Could not read device RAM. Exiting."
  exit 1
fi
TOTAL_RAM_BYTES=$((TOTAL_RAM_KB * 1024))
ZRAM_SIZE=$((TOTAL_RAM_BYTES * ZRAM_PERCENT / 100))

echo "Device RAM: ${TOTAL_RAM_KB} KB -> ZRAM size set to ${ZRAM_PERCENT}% = ${ZRAM_SIZE} bytes"

# ===== إعداد zram0 - بدون تحميل أي .ko خارجي =====
# الكيرنل الأصلي في الأجهزة الحديثة فيه zram مدمج (built-in)،
# تحميل .ko خارجي غير متوافق مع الكيرنل ممكن يعمل bootloop، فاتشال نهائياً.

if [ ! -e /dev/block/zram0 ]; then
  echo "zram0 not found on this kernel. Skipping ZRAM setup."
else
  swapoff /dev/block/zram0 2>/dev/null
  echo 1 > /sys/block/zram0/reset 2>/dev/null

  echo "${ZRAM_ALGO}" > /sys/block/zram0/comp_algorithm 2>/dev/null
  echo "${ZRAM_SIZE}" > /sys/block/zram0/disksize

  if [ "$?" -eq 0 ]; then
    mkswap /dev/block/zram0 > /dev/null 2>&1
    swapon /dev/block/zram0 > /dev/null 2>&1
    echo "zram0 active: ${ZRAM_ALGO}, ${ZRAM_SIZE} bytes"
  else
    echo "Failed to set zram0 disksize. Check ZRAM_PERCENT value."
  fi
fi

# ===== تطبيق قيم الذاكرة على طول =====
sysctl -w vm.swappiness=60 2>/dev/null
sysctl -w vm.dirty_ratio=20 2>/dev/null
sysctl -w vm.dirty_background_ratio=5 2>/dev/null
sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null

echo "sysctl values applied at: $(date) -> swappiness now = $(cat /proc/sys/vm/swappiness)" >> /data/local/tmp/turbo_debug_log.txt

# ===== لوب خفيف يعيد فرض نفس القيم كل دقيقة =====
# اتأكدنا بالاختبار إن حاجة تانية (خدمة ROM/كيرنل) بترجع تغير القيم دي
# بعد شوية من البووت، فتطبيقها مرة واحدة مش كافي على الجهاز ده.
# اللوب ده بسيط جداً (مجرد أوامر sysctl، مفيش قراءة/كتابة ملفات كبيرة)
# فتأثيره على البطارية محدود جداً مقارنة بلوب الـ WebUI.
(
  while true; do
    sysctl -w vm.swappiness=60 2>/dev/null
    sysctl -w vm.dirty_ratio=20 2>/dev/null
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null
    sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
    echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null
    sleep 60
  done
) &

# ===== انتظار اكتمال البووت (لازم للـ WebUI وقفل التطبيقات بعد الأنلوك) =====
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done

while ! pm list packages >/dev/null 2>&1; do
  sleep 2
done

MODDIR="/data/adb/modules/Turbo-Performance"
mkdir -p "$MODDIR/webroot/assets"

# ===== انتظار فتح القفل (كتابة كلمة السر) ثم قفل كل تطبيقات الخلفية =====
# مفيش API مباشر بالـ shell لحظة كتابة الباسورد، فبنراقب اختفاء نافذة
# الـ Keyguard/StatusBar كعلامة إن الشاشة اتفتحت فعلياً.
echo "[+] Waiting for screen unlock..."
UNLOCK_TRIES=0
while [ "$UNLOCK_TRIES" -lt 300 ]; do
  FOCUS=$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
  case "$FOCUS" in
    *Keyguard*|*keyguard*|*NotificationShade*)
      sleep 2
      UNLOCK_TRIES=$((UNLOCK_TRIES + 1))
      ;;
    "")
      sleep 2
      UNLOCK_TRIES=$((UNLOCK_TRIES + 1))
      ;;
    *)
      break
      ;;
  esac
done

echo "[+] Screen unlocked - running background cleaner..."
if [ -f "$MODDIR/action.sh" ]; then
  sh "$MODDIR/action.sh"
fi

# ===== لوب تحديث بيانات الـ WebUI - كل 5 ثواني بدل 2 =====
# بيكتب على التخزين، فمفيش داعي يكون سريع أوي عشان منقلّلش من عمر التخزين
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

  sleep 5
done &

exit 0