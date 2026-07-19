# ⚡ Turbo Performance - System & ZRAM Monitor

<p align="center">
  <img src="https://img.shields.io/badge/Maintained%3F-yes-00e5ff?style=for-the-badge" alt="Maintained">
  <img src="https://img.shields.io/badge/Android-Root%20Module-ff9d00?style=for-the-badge" alt="Android Root">
  <img src="https://img.shields.io/badge/Supported-KernelSU%20%7C%20APatch%20%7C%20Magisk-00ff66?style=for-the-badge" alt="Supported Managers">
</p>

An advanced, AI-optimized Android root module engineered to stabilize system performance, maximize available memory with a dynamic ZRAM engine, and provide a full-fledged real-time live web interface (WebUI).

---

## 🛠️ Key Features

* **🧠 Dynamic ZRAM Allocation:** Calculates and configs ZRAM sizes on the fly based on your device's actual physical RAM percentage. No hardcoded setups.
* **🔋 VM Lock-In Engine:** A dedicated, ultra-light background service enforces strict `sysctl` rules (swappiness, dirty ratios, cache pressure) every 60 seconds—denying internal Android overrides during heavy gaming sessions.
* **🎮 Smart Background Cleaner:** Triggered instantly upon device unlock. Uses a precise whitelist to safely purge third-party memory hogs while completely protecting your Active Launcher, SystemUI, and Root Managers from crashing.
* **📊 Live WebUI Dashboard:** A real-time, dark-themed system monitor that displays RAM, ZRAM, CPU/GPU frequencies, thermal conditions, and live battery stats with accurate health calculations (mAh / %).

---
> ⚠️ **CRITICAL DISCLAIMER & RISK NOTICE**
> This module utilizes aggressive system tweaks and configurations engineered and optimized with AI assistance. By flashing this file, you accept full responsibility for any outcomes. 
> 
> **Expected Behavior Notice:** Due to the deep system-level optimizations and memory management routines deployed instantly upon boot, your device **WILL** experience a brief, heavy interface lag/freezing for a few seconds immediately after entering your lock screen passcode. This is completely normal and expected; it is the background engine forcefully terminating third-party background services and locking in the custom kernel configurations. 
> 
> *Neither the developer nor any AI tools used shall be held responsible for bootloops, soft bricks, or any hardware wear.* **FLASH AT YOUR OWN RISK.**
