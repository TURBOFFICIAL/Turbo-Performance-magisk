system/bin/sh

echo "====================================="
echo "   🔥 SAFE BACKGROUND CLEANER 🔥      "
echo "====================================="
echo "[+] Starting RAM optimization..."
echo "-------------------------------------"

CURRENT_LAUNCHER=$(cmd package resolve-activity -c android.intent.category.HOME 2>/dev/null | grep "packageName=" | cut -d'=' -f2)
ACTIVE_ROOT_PKG=$(pm list packages | grep -E "kernelsu|magisk|apatch|next" | cut -d':' -f2)

echo "[+] Active Root Package: ${ACTIVE_ROOT_PKG:-None}"
echo "[+] Active Launcher: ${CURRENT_LAUNCHER:-None}"
echo "-------------------------------------"
echo "[+] Force-stopping ALL background apps..."

for proc in $(pm list packages -3 | cut -d':' -f2); do
    case "$proc" in
        # أدوات الروت - متقفلش
        *kernelsu*|*kernelsunext*|*magisk*|*apatch*|*tiann*|*topjohnwu*|*weishu*)
            continue
            ;;
        # اللانشر، جوجل بلاي سيرفيسز، واجهة النظام - ديه بس عشان الشاشة تفضل شغالة
        "$CURRENT_LAUNCHER"|"$ACTIVE_ROOT_PKG"|"com.android.systemui"|"com.google.android.gms"|"com.google.android.gsf")
            continue
            ;;
        *)
            am force-stop "$proc" 2>/dev/null
            ;;
    esac
done

echo "-------------------------------------"
echo "⚡ Background apps stopped. RAM freed."
echo "🎮 Ready for Gaming!"
echo "====================================="
exit 0