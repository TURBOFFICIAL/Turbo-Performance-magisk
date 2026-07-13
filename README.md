# Turbo performance 🤖⚡

An AI-engineered Magisk/KernelSU module designed to maximize ZRAM, Swappiness, and Memory management for Android devices. Developed through advanced AI collaboration for precise kernel tuning, featuring an integrated WebUI.

## 🧠 AI-Optimized Features
- **AI-Tuned ZRAM**: Sets ZRAM size to **6GB** using the highly efficient **lz4** compression algorithm.
- **Smart Memory Management**: Adjusts `swappiness` balancing for optimal RAM swap triggers.
- **Micro-Stutter Reduction**: Tries to disable `KSM` (Kernel Same-page Merging) to eliminate background CPU overhead during intense gaming.
- **Advanced Sysctl Tuning**: Extra memory parameters optimized via AI for peak performance.
- **Integrated WebUI**: View module status and monitor tweaks directly from a web interface.

## ⚠️ Important Note (Post-Boot Behavior)
- **Brief Lag After Boot**: After every restart, the mobile device will experience a **brief lag/freeze for a short duration**. This is completely normal and happens while the system triggers the `post-fs-data` scripts and the AI configurations fully initialize. Performance will return to a super-smooth state immediately after.

## 🛠️ Requirements
- Android Device with Magisk or KernelSU installed.
- Root access.
<img width="719" height="1431" alt="072153ec-1903-4e15-b2e9-5defbb0f0c75" src="https://github.com/user-attachments/assets/994b0ac1-c1e4-4f93-9214-d8b35f6f6cdc" />
