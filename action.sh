#!/system/bin/sh

echo "====================================="
echo "   🔥 DEEP BACKGROUND CLEANER 🔥     "
echo "====================================="
echo "[+] Starting deep RAM optimization..."
echo "-------------------------------------"

# 1. Force-stop all 3rd party background apps
echo "[+] Terminating background applications..."
for proc in $(pm list packages -3 | cut -d':' -f2); do
    # Whitelist root managers to prevent installation or UI crashes
    if [ "$proc" != "io.github.tiann.kernelsu" ] && [ "$proc" != "com.topjohnwu.magisk" ]; then
        am force-stop "$proc"
    fi
done

# 2. Flush RAM and CPU cache layers
echo "[+] Flushing system caches (Drop Caches)..."
sync
echo 3 > /proc/sys/vm/drop_caches

# 3. Release remaining cached memory assets
am kill-all

echo "-------------------------------------"
echo "⚡ RAM successfully optimized! ⚡"
echo "🎮 Memory cleared. Device is ready for gaming."
echo "====================================="
exit 0