MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.prop"

# 如果配置文件不存在则退出
if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.prop not found! Exiting."
  exit 1
fi

# 加载变量
. "$CONFIG_FILE"

# 检查变量是否定义
if [ -z "$ZRAM_ALGO" ] || [ -z "$ZRAM_SIZE" ]; then
  echo "ZRAM_ALGO or ZRAM_SIZE is not set! Exiting."
  exit 1
fi

# تم حذف الـ sleep 30 من هنا بناءً على طلبك ليعمل فوراً 🚀

# 关闭并重置所有现有 zram 设备
for dev in /dev/block/zram*; do
  if [ -e "$dev" ]; then
    echo "Disabling $dev"
    swapoff "$dev" 2>/dev/null
    echo 1 > "/sys/block/$(basename "$dev")/reset"
  fi
done

# 尝试卸载模块，确保干净状态
if lsmod | grep -q "^zram"; then
  echo "Removing existing zram module"
  rmmod zram
  sleep 1
fi

# 加载自定义 zstdn 模块（如果存在）
if [ -f "$MODDIR/zram/zstdn.ko" ]; then
  su -c insmod "$MODDIR/zram/zstdn.ko"
fi

# 加载 zram 模块（仅一次）
if ! lsmod | grep -q "^zram"; then
  su -c insmod "$MODDIR/zram/zram.ko"
else
  echo "zram module already loaded, skipping"
fi

# 配置 zram0（确保只有一个）
if [ -e /dev/block/zram0 ]; then
  sleep 5
  echo '1' > /sys/block/zram0/reset
  echo '0' > /sys/block/zram0/disksize
  echo '8' > /sys/block/zram0/max_comp_streams
  echo "${ZRAM_ALGO}" > /sys/block/zram0/comp_algorithm
  echo "${ZRAM_SIZE}" > /sys/block/zram0/disksize
  mkswap /dev/block/zram0 > /dev/null 2>&1
  swapon /dev/block/zram0 > /dev/null 2>&1
  echo "zram0 is now active with ${ZRAM_ALGO} and size ${ZRAM_SIZE}"
else
  echo "zram0 not found, failed to initialize swap"
  exit 1
fi

# 检查是否还有多余 zram 设备
zram_count=$(ls /sys/block/ | grep -c '^zram')
if [ "$zram_count" -gt 1 ]; then
  echo "Warning: More than one zram device present!"
  ls /sys/block/ | grep '^zram'
fi

# =======================================================
# 🔥 التعديلات الفاجرة الإضافية للأداء الأقصى والألعاب 🔥
# =======================================================

# 1. إجبار النظام على الطيران بالـ ZRAM
# غير سطر sysctl القديم بـ:
su -c "echo 160 > /proc/sys/vm/swappiness"

sysctl -w vm.page-cluster=0

# 2. قفل الـ KSM لمنع الفريم دروب وحرارة المعالج
# ضيف السطر ده جوه الـ while true في السكربت
if [ -f /sys/kernel/mm/ksm/run ]; then
  echo 0 > /sys/kernel/mm/ksm/run
fi

# 3. تحسين الكاش وسرعة استجابة الذاكرة ومنع تجمد اللعبة
sysctl -w vm.dirty_ratio=30
sysctl -w vm.dirty_background_ratio=10
sysctl -w vm.vfs_cache_pressure=125

# سكربت الخلفية لتحديث البيانات الحقيقية لـ WebUI
MODDIR="/data/adb/modules/Turbo-Performance"
mkdir -p "$MODDIR/webroot/assets"

while true; do
  # 1. قراءة الذاكرة
  MEMINFO=$(cat /proc/meminfo)
  MEM_TOTAL=$(echo "$MEMINFO" | awk '/MemTotal/ {print $2}')
  MEM_AVAIL=$(echo "$MEMINFO" | awk '/MemAvailable/ {print $2}')
  SWAP_TOTAL=$(echo "$MEMINFO" | awk '/SwapTotal/ {print $2}')
  SWAP_FREE=$(echo "$MEMINFO" | awk '/SwapFree/ {print $2}')
  SWAPPINESS=$(cat /proc/sys/vm/swappiness)

  # 2. قراءة المعالج والـ GPU (مسارات السناب دراجون الحقيقية)
  CPU_TEMP=$(cat /sys/class/thermal/thermal_zone22/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp)
  CPU_FREQ=$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq 2>/dev/null || cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq)
  GPU_FREQ=$(cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null || cat /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq)

  # 3. قراءة البطارية (إضافة قراءة الصحة والسعة)
  BAT_LEVEL=$(cat /sys/class/power_supply/battery/capacity)
  BAT_TEMP=$(cat /sys/class/power_supply/battery/temp)
  BAT_NOW=$(cat /sys/class/power_supply/battery/current_now)
  
  # السطور الجديدة لقراءة السعة الحالية والتصميمية (mAh)
  BAT_CHARGE_FULL=$(cat /sys/class/power_supply/battery/charge_full 2>/dev/null || cat /sys/class/power_supply/battery/charge_full_design)
  BAT_DESIGN_FULL=$(cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || echo "5000000") # حطينا 5000 كا احتياط لو مش مقروءة


  # كتابة البيانات بصيغة JSON نظيفة جداً داخل الفولدر الصحيح
  echo "{" > "$MODDIR/webroot/assets/stats.json"
  echo "  \"memTotal\": $MEM_TOTAL," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"memAvail\": $MEM_AVAIL," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"swapTotal\": $SWAP_TOTAL," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"swapFree\": $SWAP_FREE," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"swappiness\": $SWAPPINESS," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"cpuTemp\": \"$CPU_TEMP\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"cpuFreq\": \"$CPU_FREQ\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"gpuFreq\": \"$GPU_FREQ\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"batLevel\": \"$BAT_LEVEL\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"batTemp\": \"$BAT_TEMP\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"batNow\": \"$BAT_NOW\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"batChargeFull\": \"$BAT_CHARGE_FULL\"," >> "$MODDIR/webroot/assets/stats.json"
  echo "  \"batDesignFull\": \"$BAT_DESIGN_FULL\"" >> "$MODDIR/webroot/assets/stats.json"
  echo "}" >> "$MODDIR/webroot/assets/stats.json"


  sleep 2
done &

exit 0
