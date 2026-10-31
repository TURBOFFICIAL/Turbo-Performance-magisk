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

# ===== ZRAM setup =====
# ZRAM is configured ONLY by zram.prop in the module folder: edit
# ZRAM_SIZE_MB there and reboot. The WebUI never touches it. It is applied
# immediately when service.sh starts (no boot_completed wait).
ZRAM_FILE="$MODDIR/zram.prop"
ZRAM_NODE="/dev/block/zram0"
ZRAM_SYS="/sys/block/zram0"
DEBUG_LOG="/data/local/tmp/turbo_boot_debug.log"

zlog() { echo "$(date '+%H:%M:%S') $*" >> "$DEBUG_LOG" 2>/dev/null; }

# Write a value to a sysfs file; log it if the kernel refuses it.
zwrite() {
  if ! echo "$1" > "$2" 2>/dev/null; then
    zlog "FAILED: could not write '$1' to $2"
    return 1
  fi
}

# Read KEY from zram.prop. Tolerates spaces around '=', quotes, Windows
# (CRLF) line endings and a trailing "# comment", and ignores commented-out
# lines. Last value wins.
zprop() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$ZRAM_FILE" 2>/dev/null \
    | tail -n 1 | cut -d= -f2- | cut -d'#' -f1 | tr -d ' \t\r"'"'"
}

setup_zram() {
  size_mb=$(zprop ZRAM_SIZE_MB)
  algo=$(zprop ZRAM_ALGO)
  [ -z "$algo" ] && algo="lz4"

  # A typo in the file must never break the phone: if the value is not
  # valid, ZRAM is simply left the way the system set it up.
  case "$size_mb" in
    ''|*[!0-9]*)
      zlog "zram.prop: ZRAM_SIZE_MB is missing or not a number ('$size_mb') - leaving ZRAM unchanged."
      return 1 ;;
  esac
  if [ "$size_mb" -ne 0 ] && { [ "$size_mb" -lt 128 ] || [ "$size_mb" -gt 16384 ]; }; then
    zlog "zram.prop: ZRAM_SIZE_MB=$size_mb is out of range (use 0 to turn off, or 128-16384) - leaving ZRAM unchanged."
    return 1
  fi
  if [ ! -e "$ZRAM_NODE" ]; then
    zlog "ERROR: $ZRAM_NODE not found on this kernel"
    return 1
  fi

  old_bytes=$(cat "$ZRAM_SYS/disksize" 2>/dev/null)
  zlog "Requested: ${size_mb} MB, algo=${algo} (previous disksize: ${old_bytes:-unknown} bytes)"

  swapoff "$ZRAM_NODE" >> "$DEBUG_LOG" 2>&1
  zwrite 1 "$ZRAM_SYS/reset"

  if [ "$size_mb" -eq 0 ]; then
    zlog "ZRAM turned off (ZRAM_SIZE_MB=0)"
    return 0
  fi

  # awk does the MB -> bytes math so large sizes can never overflow the
  # shell's integer arithmetic (and leading zeros are not read as octal).
  new_bytes=$(awk -v mb="$size_mb" 'BEGIN { printf "%.0f", mb * 1024 * 1024 }')
  zwrite "$algo" "$ZRAM_SYS/comp_algorithm"
  if ! zwrite "$new_bytes" "$ZRAM_SYS/disksize"; then
    # Never leave the phone without swap because of a failed resize.
    case "$old_bytes" in ''|0|*[!0-9]*) return 1 ;; esac
    zlog "Falling back to the previous size ($old_bytes bytes)"
    zwrite "$old_bytes" "$ZRAM_SYS/disksize" || return 1
  fi

  mkswap "$ZRAM_NODE" >> "$DEBUG_LOG" 2>&1
  swapon "$ZRAM_NODE" >> "$DEBUG_LOG" 2>&1
  return 0
}

# ---- run ----
: > "$DEBUG_LOG" 2>/dev/null
zlog "service.sh started"
# Recreate zram.prop with defaults if it is missing.
if [ ! -f "$ZRAM_FILE" ]; then
  cat > "$ZRAM_FILE" <<'ZEOF'
# ZRAM settings - the ONLY place to change ZRAM.
# Edit the numbers below, save the file, then REBOOT for it to take effect.
#
# ZRAM_SIZE_MB : ZRAM size in MB
#                1024 = 1 GB    2048 = 2 GB    3072 = 3 GB
#                4096 = 4 GB    5120 = 5 GB    6144 = 6 GB
#                0    = turn ZRAM off completely
#                (allowed: 0, or anything from 128 to 16384)
# ZRAM_ALGO    : compression algorithm. lz4 is fast (default).
#                zstd compresses harder but uses more CPU (if your kernel has it).

ZRAM_SIZE_MB=2048
ZRAM_ALGO=lz4
ZEOF
  zlog "zram.prop was missing - created it with the defaults"
fi
setup_zram
zlog "Result: disksize=$(cat "$ZRAM_SYS/disksize" 2>/dev/null) bytes | /proc/swaps: $(grep zram /proc/swaps 2>/dev/null)"

apply_sysctl() {
  sysctl -w vm.swappiness=60 vm.dirty_ratio=20 vm.dirty_background_ratio=5 vm.vfs_cache_pressure=100 2>/dev/null
  echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null

  # watermark_scale_factor: keeps a larger free-memory headroom so the
  # kernel reclaims proactively in the background (kswapd) instead of
  # stalling the app in front of you to reclaim memory synchronously.
  # 200 = 2% of zone size (kernel default is usually 10 = 0.1%). This is a
  # well-established tuning for smoother behavior under memory pressure.
  sysctl -w vm.watermark_scale_factor=200 2>/dev/null

  # page-cluster: number of pages read in one swap-in operation, as a
  # power of 2 (default 3 = 8 pages). ZRAM is fast RAM-to-RAM compressed
  # swap, so reading extra neighboring pages "just in case" mostly wastes
  # CPU decompressing pages that may never be used. Setting it to 0 (single
  # page per swap-in) is the standard recommendation specifically for
  # ZRAM-based setups and noticeably reduces wasted CPU work.
  sysctl -w vm.page-cluster=0 2>/dev/null
}

# ===== Wait for boot completion before the sysctl / I/O tuning =====
# ZRAM was already set up above, immediately. The sysctl values wait for
# boot to finish because ROM services were observed overriding them
# (e.g. swappiness) after boot.
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done
while ! pm list packages >/dev/null 2>&1; do
  sleep 2
done

MODDIR="/data/adb/modules/Turbo-Performance"
mkdir -p "$MODDIR/webroot/assets"

# Snapshot of ZRAM now that boot is complete. If this differs from the
# "Result" line written earlier, something in the ROM changed ZRAM after we
# set it - that is exactly what the debug log is here to reveal.
zlog "Boot completed: disksize=$(cat "$ZRAM_SYS/disksize" 2>/dev/null) bytes | /proc/swaps: $(grep zram /proc/swaps 2>/dev/null)"
( sleep 120; zlog "120s after boot completed: disksize=$(cat "$ZRAM_SYS/disksize" 2>/dev/null) bytes | /proc/swaps: $(grep zram /proc/swaps 2>/dev/null)" ) &

# Ensure default setting files exist so the WebUI/action.sh never fail
# reading them on a fresh install (first boot after installing the module)
[ -f "$MODDIR/exclude_apps.txt" ] || touch "$MODDIR/exclude_apps.txt"
[ -f "$MODDIR/trigger_apps.txt" ] || touch "$MODDIR/trigger_apps.txt"
# config.prop ships with the module itself, so it always exists already -
# no need to generate a default copy here.

# ===== I/O scheduler + read-ahead tuning =====
# The default scheduler (cfq/bfq) is designed for spinning disks and adds
# unnecessary CPU overhead on flash storage (UFS/eMMC). noop/none lets the
# flash controller handle ordering itself, which it's already optimized
# for. Read-ahead is bumped from the usual 128KB default to 512KB so apps
# load a bit faster (small, fixed RAM cost per device, not per-app).
apply_io_tuning() {
  for dev in /sys/block/*; do
    devname=$(basename "$dev")
    case "$devname" in
      zram*|loop*|ram*) continue ;;
    esac

    if [ -f "$dev/queue/scheduler" ]; then
      SCHED_LIST=$(cat "$dev/queue/scheduler" 2>/dev/null)
      case "$SCHED_LIST" in
        *none*) echo none > "$dev/queue/scheduler" 2>/dev/null ;;
        *noop*) echo noop > "$dev/queue/scheduler" 2>/dev/null ;;
        *deadline*) echo deadline > "$dev/queue/scheduler" 2>/dev/null ;;
      esac
    fi

    [ -f "$dev/queue/read_ahead_kb" ] && echo 512 > "$dev/queue/read_ahead_kb" 2>/dev/null
  done
}

# ===== sysctl + I/O tuning (applied once boot is fully complete) =====
apply_sysctl
apply_io_tuning

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
# is opened. Disabled by default (TRIGGER_ENABLED=false in config.prop,
# editable from the WebUI). Re-reads settings every cycle so toggling the
# feature or editing the trigger app list from the WebUI takes effect
# immediately, with no reboot needed. =====
(
  LAST_FOCUS_PKG=""
  while true; do
    TRIGGER_ENABLED="false"
    [ -f "$MODDIR/config.prop" ] && . "$MODDIR/config.prop"

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

# ===== Optional feature: low-memory auto-clean watchdog. Disabled by
# default (LOWMEM_ENABLED=false in config.prop, editable from the
# WebUI). Watches available RAM % and runs the same cleanup as the manual
# button if it drops below the user's threshold, with a cooldown so it
# can't thrash repeatedly. Re-reads settings every cycle, so toggling or
# changing the threshold from the WebUI takes effect immediately. =====
(
  LOWMEM_LAST_TRIGGER=0
  while true; do
    LOWMEM_ENABLED="false"
    LOWMEM_THRESHOLD=15
    [ -f "$MODDIR/config.prop" ] && . "$MODDIR/config.prop"

    if [ "$LOWMEM_ENABLED" = "true" ]; then
      eval "$(awk '/^(MemTotal|MemAvailable):/{gsub(":","");print $1"="$2}' /proc/meminfo)"
      if [ -n "$MemTotal" ] && [ "$MemTotal" -gt 0 ] 2>/dev/null; then
        AVAIL_PCT=$((MemAvailable * 100 / MemTotal))
        if [ "$AVAIL_PCT" -lt "$LOWMEM_THRESHOLD" ]; then
          NOW=$(date +%s 2>/dev/null || echo 0)
          # Cooldown: don't re-trigger more than once every 2 minutes,
          # so it can't repeatedly force-stop apps back to back.
          if [ $((NOW - LOWMEM_LAST_TRIGGER)) -ge 120 ]; then
            sh "$MODDIR/action.sh" >/dev/null 2>&1
            LOWMEM_LAST_TRIGGER=$NOW
          fi
        fi
      fi
      sleep 20
    else
      # Feature disabled (default) - just re-check the flag periodically,
      # no /proc/meminfo reads or arithmetic in between.
      sleep 30
    fi
  done
) &

# ملحوظة: لوب كتابة stats.json اتشال من هنا نهائياً. دلوقتي الـ WebUI نفسه
# بينادي get_stats.sh مباشرة وقت ما يكون مفتوح بس (شوف monitor.js)،
# فمفيش أي عملية بتشتغل في الخلفية لحساب الـ RAM/ZRAM لما تقفل الـ WebUI.

# مهم: نستنى اللوبات بدل ما نعمل exit فوري. لو السكريبت خرج فوراً، الـ PID
# اللي اتسجل في ملف الـ lock فوق بيبقى PID لعملية ميتة بالفعل (اللوبات
# شغالة بـ PIDs تانية خالص تحت &)، فأي تنفيذ تاني لـ service.sh هيفتكر غلط
# إن مفيش حاجة شغالة ويطلق لوبات مكررة. الـ wait بيخلي السكريبت نفسه حي
# طول الوقت، فالـ lock يفضل صحيح وفعّال فعلاً.
wait
