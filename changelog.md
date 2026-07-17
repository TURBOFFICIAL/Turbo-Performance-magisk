# ⚡ Turbo Performance v1.3 (The Ultimate Golden Update)

A powerful performance optimization module designed for Android, now with a fully interactive and real-time WebUI dashboard for **KernelSU-Next**, **APatch**, and **Magisk**.

---

## ⚠️ IMPORTANT WARNINGS & DISCLAIMER (READ BEFORE FLASHING)
* **⚡ FLASH AT YOUR OWN RISK:** This module modifies low-level kernel configurations, system memory (RAM), and ZRAM allocations. While it has been thoroughly tested for safety, we are not responsible for any bootloops, hardware strain, system instability, or unexpected behavior on your device.
* **Backup is Recommended (v1.1 Legacy Check):** Since this module executes deep modifications to physical RAM and Swap management, it is highly recommended to have a recovery backup or a key-combination safe mode ready in case your custom ROM's kernel reacts unexpectedly.
* **Compatibility Check (v1.1 Legacy Check):** Ensure that your current kernel supports custom ZRAM configurations before adjusting the variables in `config.prop`. Sticking to the default recommended size is highly advised for first-time flashing.
* **DO NOT** include the `update.json` file inside your local flashable ZIP. It should only exist on your remote GitHub repository! Including it inside the ZIP will break the update cycle.
* **Deep RAM Cleaner Safeties:** While our new `action.sh` is fully optimized to ignore crucial system packages, please ensure your system launcher is set to default before running deep cleanup to avoid temporary home screen redraws.
* **First Boot Notice:** After flashing v1.2, a full device reboot is required to activate the locked VM Swappiness (60) and initialize the background monitoring loop.

---

## 📝 What's New in Today's v1.3 Update

### 🎮 [ Performance & Gaming Intelligence ]
* **Smart Post-Unlock Auto Clean (NEW):** Integrated an intelligent boot trigger inside `service.sh`. The module now silently waits until the device completely boots up and the user unlocks the lockscreen (enters password/fingerprint). Once the system launcher fully loads, it automatically executes the Deep RAM Cleaner (`action.sh`) after a 5-second delay to ensure maximum free RAM right from the start without causing any system UI lag. system files instead of displaying static, hardcoded indicators.
* **Clean Battery Monitoring:** Integrated real-time capacity tracking (Charge Full vs. Design Capacity in **mAh**) to accurately calculate your precise Battery Health percentage in a single, well-formatted row.

---

## 🛠️ Module Structure Checklist
Before zipping your release, ensure your `.zip` archive only contains the following structure:

```text
Turbo-Performance-v1.2.zip
├── webroot/
│   ├── assets/
│   ├── index.html   <-- (Clean layout with LTR forced)
│   └── monitor.js
├── zram/
├── service.sh       <-- (The background loop & VM lock)
├── post-fs-data.sh  <-- (Updated to 60 swappiness)
├── action.sh        <-- (The new Deep Safe RAM cleaner)
├── module.prop      <-- (Update versionCode to 3, version to 1.2)
└── config.prop
