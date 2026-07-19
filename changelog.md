## 🚀 Turbo Performance v1.4 - Re-Engineered Stability & WebUI 🧠

> ⚠️ **Disclaimer / Note:** This version features advanced configurations engineered and optimized with AI assistance. Use at your own risk. Device may experience a brief, temporary lag for a few seconds after booting until all background engine scripts fully initialize.

### 🛠️ What's New & Changelog:

* **🧠 Smart ZRAM Engine:** 
  - Dropped external `.ko` kernel modules completely to eliminate bootloop risks.
  - ZRAM size is now calculated dynamically based on a percentage (`ZRAM_PERCENT`) of your actual device total RAM, rather than a hardcoded value.

* **🔋 Persistent VM Tuning (Anti-Override):**
  - Moved memory adjustments out of `post-fs-data.sh` to prevent ROM overrides.
  - Added a super-lightweight background loop that forces optimal `sysctl` entries (swappiness, dirty ratios) every 60 seconds to lock in gaming stability.

* **🎮 Safe Background Cleaner (`action.sh`):**
  - Re-engineered the killer script to automatically detect and whitelist your active Launcher, SystemUI, Google Services, and Root Manager packages (Magisk, KernelSU, APatch) to prevent interface crashes.

* **📊 AI-Enhanced WebUI & Storage Protection:**
  - Extended the dashboard write-interval to 5 seconds to reduce flash storage overhead and extend UFS memory lifespan.
  - Implemented dynamic DOM manipulation to auto-inject a separate **GPU Status card** and an **Accurate Battery Health tracker (mAh / %)** on the fly.
