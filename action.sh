#!/system/bin/sh

echo "====================================="
echo "   🔥 DEEP BACKGROUND CLEANER 🔥     "
echo "====================================="
echo "[+] Starting deep RAM optimization..."
echo "-------------------------------------"

# 1. تحديد اللانشر النشط تلقائياً
CURRENT_LAUNCHER=$(cmd shortcut get-default-launcher | awk '{print $NF}' 2>/dev/null)

# 2. جلب حزمة مدير الروت الفعلي النشط حالياً في النظام
ACTIVE_ROOT_PKG=$(pm list packages | grep -E "kernelsu|magisk|apatch|next" | cut -d':' -f2)

echo "[+] Active Root Package: ${ACTIVE_ROOT_PKG:-None}"
echo "[+] Active Launcher: ${CURRENT_LAUNCHER:-None}"
echo "-------------------------------------"
echo "[+] Force-stopping heavy background apps..."

# 3. قفل تطبيقات الطرف الثالث بقوة وأمان تام
for proc in $(pm list packages -3 | cut -d':' -f2); do
    # فلترة حديدية: لو اسم التطبيق بيحتوي على أي كلمة من كلمات الحماية.. فوتّه فوراً ومتقفلوش!
    case "$proc" in
        *kernelsu*|*kernelsunext*|*magisk*|*apatch*|*tiann*|*topjohnwu*|*weishu*)
            # تخطي أدوات الروت تماماً لمنع قفلها
            continue
            ;;
        "$CURRENT_LAUNCHER"|"$ACTIVE_ROOT_PKG"|"com.android.systemui"|"com.google.android.gms")
            # تخطي اللانشر، خدمات جوجل، وواجهة النظام الأساسية
            continue
            ;;
        *)
            # قفل أي تطبيق طرف ثالث آخر بقوة من الجذور لتوفر الرام بالكامل
            am force-stop "$proc"
            ;;
    esac
done

# 4. تنظيف الطبقات العميقة لكاش الرام والمعالج
echo "[+] Flushing system memory caches..."
sync
sleep 0.5
echo 3 > /proc/sys/vm/drop_caches

# 5. تنظيف بقايا الذاكرة وإجبار الـ ZRAM على الكبس
echo "[+] Releasing unused memory blocks..."
am kill-all
echo 1 > /proc/sys/vm/compact_memory

echo "-------------------------------------"
echo "⚡ RAM successfully optimized! ⚡"
echo "🎮 Background apps terminated. Ready for Gaming!"
echo "====================================="
exit 0
