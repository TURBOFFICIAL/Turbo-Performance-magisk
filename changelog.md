═════════════════════════════════════════════════════
     TURBO PERFORMANCE v1.5 - UPDATE CHANGELOG
═════════════════════════════════════════════════════

📝 WHAT'S CHANGED:

🔴 REMOVED: Automatic App Termination on Screen Unlock
   └─ Was causing crashes during login/payment operations
   └─ Now manual only - tap action button when you want

✅ IMPROVED: Stable sysctl Enforcement
   └─ Parameters now persist (checked every 60 seconds)
   └─ Memory optimization stays locked in even if ROM changes values

📊 RESULTS:
   • Better stability (no crashes during sensitive ops)
   • Better battery life (no unlock detection polling)
   • Full user control over when apps are cleaned

═════════════════════════════════════════════════════

📥 FILES MODIFIED:
   ✓ service.sh (MUST REPLACE)

📥 FILES UNCHANGED (no need to replace):
   • config.prop
   • post-fs-data.sh
   • action.sh
   • monitor.js
   • style.css
   • index.html

═════════════════════════════════════════════════════

🎮 HOW TO USE:
   1. Memory optimization runs automatically
   2. To clean background apps: Tap action button manually
   3. Best time to tap: Before gaming, when idle
   4. Avoid tapping during: Login, purchases, file transfers

═════════════════════════════════════════════════════

⚠️ IMPORTANT:
   After updating, reboot your device!

═════════════════════════════════════════════════════
v1.5 • July 19, 2026 • Stability Update

