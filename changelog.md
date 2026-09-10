═════════════════════════════════════════════════════
   TURBO PERFORMANCE v1.8 - RELIABILITY & CONTROL UPDATE
═════════════════════════════════════════════════════

⚡ EFFICIENCY:

🔴 REMOVED: Permanent Background Stats Loop
   └─ Stats used to run every 3s forever, even with the
      WebUI closed - now fetched on-demand, only while
      the WebUI is open. Zero overhead when closed.

🔒 FIXED: Duplicate-Run Lock File
   └─ Moved from /dev/shm (often missing on Android) to
      a guaranteed path - duplicate prevention now works

⚡ OPTIMIZED: Memory Reading
   └─ ~9 shell processes per stats read reduced to 1

═════════════════════════════════════════════════════

🛠️ RELIABILITY:

🔴 FIXED: WebUI Not Loading Stats ("Reading..." Stuck)
   └─ Was loading its shell-bridge library from the
      internet, which the manager's WebView blocks/fails
      to load reliably
   └─ Now uses a local, network-free bridge - works
      offline, every time

🔴 FIXED: "Failed to set zram0 disksize" Error
   └─ ZRAM resize now waits and confirms each step
      (swapoff, reset) actually completed before moving
      to the next, with automatic retries
   └─ Clear, specific error messages per step instead of
      one generic failure message

═════════════════════════════════════════════════════

✨ NEW FEATURES:

📊 Available RAM & Available ZRAM
   └─ Dashboard now also shows free RAM and free ZRAM,
      with percentages, next to the existing used stats

⚙️ ZRAM Size Presets
   └─ Quick-select buttons: 25% / 50% (Auto) / 75% / 100%
   └─ Plus Custom, for entering your own size in MB

🧹 Smarter ZRAM Apply
   └─ Tapping "Apply ZRAM Setting" now automatically
      closes background apps FIRST, then resizes ZRAM -
      much higher success rate, since less data needs to
      be moved out of ZRAM during the resize
   └─ Clear success/failure message every time, showing
      exactly what was applied

═════════════════════════════════════════════════════

📥 FILES MODIFIED:
   ✓ service.sh
   ✓ apply_zram.sh
   ✓ index.html
   ✓ style.css
   ✓ monitor.js

📥 NEW FILES :
   ✓ get_stats.sh
   ✓ webroot/assets/ksu-bridge.js

📥 UNCHANGED:
   • config.prop, post-fs-data.sh, action.sh,
     exclude_apps.txt, trigger_apps.txt

═════════════════════════════════════════════════════

⚠️ IMPORTANT: Reboot after updating.

═════════════════════════════════════════════════════
v1.8 • September 9, 2026 • Reliability & Control Update
