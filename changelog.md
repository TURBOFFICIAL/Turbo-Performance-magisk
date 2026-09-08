═════════════════════════════════════════════════════
     TURBO PERFORMANCE v1.7 - CUSTOMIZATION UPDATE
═════════════════════════════════════════════════════

✨ NEW FEATURES:

📊 SIMPLIFIED DASHBOARD
   └─ WebUI now shows only what matters: RAM and ZRAM
   └─ Removed CPU/GPU/Battery/VM cards for a cleaner view

🚫 EXCLUDED APPS LIST (NEW)
   └─ Choose apps that should NEVER be closed
   └─ Applies to both the manual action button and the
      new auto-close trigger
   └─ Add/remove apps directly from the WebUI

🎯 AUTO-CLOSE ON APP OPEN (NEW)
   └─ Pick specific apps that, when opened, automatically
      close all other background apps
   └─ Fully optional - OFF by default
   └─ Toggle on/off anytime from the WebUI, no reboot needed
   └─ Respects your Excluded Apps list

⚙️ LIVE ZRAM SIZE CONTROL (NEW)
   └─ Change ZRAM size directly from the WebUI - no reboot!
   └─ Two modes:
       • Auto (default) - 50% of device RAM, adjusts automatically
       • Manual - set your own fixed size in MB
   └─ Changes apply immediately when you tap Save

═════════════════════════════════════════════════════

📥 FILES MODIFIED:
   ✓ service.sh       (MUST REPLACE)
   ✓ action.sh         (MUST REPLACE)
   ✓ index.html        (MUST REPLACE)
   ✓ monitor.js         (MUST REPLACE)
   ✓ style.css          (MUST REPLACE)

📥 NEW FILES (add these too):
   ✓ apply_zram.sh
   ✓ exclude_apps.txt   (empty by default)
   ✓ trigger_apps.txt   (empty by default)
   ✓ user_config.prop   (default settings)

📥 UNCHANGED:
   • config.prop
   • post-fs-data.sh

═════════════════════════════════════════════════════

🎮 HOW TO USE THE NEW FEATURES:

1. Excluded Apps:
   Open WebUI → "Excluded Apps" card → tap "+ Add App" →
   pick the app you never want closed.

2. Auto-Close on App Open:
   Open WebUI → "Auto-Close on App Open" card → add the
   app(s) that should trigger cleanup → flip the switch ON.
   Example: add your game, and every time you open it,
   background apps get closed automatically.

3. ZRAM Size:
   Open WebUI → "ZRAM Size" card → choose Auto or Manual →
   (if Manual) enter size in MB → tap "Save ZRAM Setting".
   Note: You may feel a brief freeze (under 1 second) while
   ZRAM is being resized - this is normal.

═════════════════════════════════════════════════════

⚠️ IMPORTANT NOTES:

   • The app lists show package names (e.g. com.whatsapp),
     not friendly app names/icons - this is a shell/WebUI
     limitation, not a bug.
   • Your root manager app, launcher, and system UI are
     ALWAYS protected and cannot be closed, even if not in
     your excluded list.
   • After updating, reboot your device once to ensure all
     new files are set up correctly.

═════════════════════════════════════════════════════
v1.7 • July 19, 2026 • Customization Update
